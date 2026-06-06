package main

import (
	"crypto/tls"
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"net"
	"os"
	"sync"
	"time"

	shared "th/shared/protocol"
)

const (
	firstMessageTimeout = 10 * time.Second
	agentSendTimeout    = 5 * time.Second
)

// ---------------------------------------------------------------------------
// Rate limiting / ban
// ---------------------------------------------------------------------------

type banTracker struct {
	mu             sync.Mutex
	ipFails        map[string]int
	ipBanned        map[string]bool
	deviceFails    map[string]int
	deviceBanned    map[string]bool
	ipMaxFails     int
	deviceMaxFails int
}

func newBanTracker(ipMax, deviceMax int) *banTracker {
	return &banTracker{
		ipFails:        make(map[string]int),
		ipBanned:        make(map[string]bool),
		deviceFails:    make(map[string]int),
		deviceBanned:    make(map[string]bool),
		ipMaxFails:     ipMax,
		deviceMaxFails: deviceMax,
	}
}

// recordIPFail increments the failure count for ip. Returns true if the IP
// reached the ban threshold (and is now banned).
func (b *banTracker) recordIPFail(ip string) bool {
	b.mu.Lock()
	defer b.mu.Unlock()

	if b.ipBanned[ip] {
		return true
	}
	b.ipFails[ip]++
	if b.ipFails[ip] >= b.ipMaxFails {
		b.ipBanned[ip] = true
		delete(b.ipFails, ip)
		return true
	}
	return false
}

// recordDeviceFail increments the failure count for deviceId. Returns true if
// the deviceId reached the ban threshold.
func (b *banTracker) recordDeviceFail(deviceID string) bool {
	b.mu.Lock()
	defer b.mu.Unlock()

	if b.deviceBanned[deviceID] {
		return true
	}
	b.deviceFails[deviceID]++
	if b.deviceFails[deviceID] >= b.deviceMaxFails {
		b.deviceBanned[deviceID] = true
		delete(b.deviceFails, deviceID)
		return true
	}
	return false
}

func (b *banTracker) isIPBanned(ip string) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.ipBanned[ip]
}

func (b *banTracker) isDeviceBanned(deviceID string) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.deviceBanned[deviceID]
}

func (b *banTracker) ipFailCount(ip string) int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.ipFails[ip]
}

func (b *banTracker) deviceFailCount(deviceID string) int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.deviceFails[deviceID]
}

// ---------------------------------------------------------------------------
// Relay server
// ---------------------------------------------------------------------------

type relayServer struct {
	relayAPIKey string
	ban         *banTracker

	mu       sync.Mutex
	agents   map[string]*agentConn
	sessions map[string]*pendingSession
}

type agentConn struct {
	deviceID     string
	conn         net.Conn
	send         chan shared.ControlMessage
	capabilities []string
	plugins      []shared.PluginInfo
}

type pendingSession struct {
	deviceID  string
	sessionID string
	client    net.Conn
	createdAt time.Time
}

func main() {
	addr := flag.String("addr", ":8080", "TCP listen address")
	relayAPIKey := flag.String("relay-api-key", "", "shared relay API key; empty disables relay auth")
	tlsCert := flag.String("tls-cert", "", "TLS certificate file; requires -tls-key")
	tlsKey := flag.String("tls-key", "", "TLS private key file; requires -tls-cert")
	ipBanThreshold := flag.Int("ip-ban-threshold", 3, "failed auth attempts before IP is permanently banned")
	deviceBanThreshold := flag.Int("device-ban-threshold", 10, "failed auth attempts before deviceId is permanently banned")
	flag.Parse()

	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelInfo})))

	s := &relayServer{
		relayAPIKey: *relayAPIKey,
		ban:         newBanTracker(*ipBanThreshold, *deviceBanThreshold),
		agents:      make(map[string]*agentConn),
		sessions:    make(map[string]*pendingSession),
	}

	ln, err := listen(*addr, *tlsCert, *tlsKey)
	if err != nil {
		slog.Error("listen failed", "err", err)
		os.Exit(1)
	}
	defer ln.Close()

	mode := "tcp"
	if *tlsCert != "" || *tlsKey != "" {
		mode = "tls"
	}
	slog.Info("relay listening", "addr", *addr, "mode", mode, "ipBanThreshold", *ipBanThreshold, "deviceBanThreshold", *deviceBanThreshold)
	if *tlsCert == "" {
		slog.Warn("TLS is not enabled — relay traffic is unencrypted; set -tls-cert and -tls-key")
	}

	for {
		conn, err := ln.Accept()
		if err != nil {
			slog.Error("accept", "err", err)
			continue
		}
		go s.handleConn(conn)
	}
}

func listen(addr, certFile, keyFile string) (net.Listener, error) {
	if certFile == "" && keyFile == "" {
		return net.Listen("tcp", addr)
	}
	if certFile == "" || keyFile == "" {
		return nil, errors.New("both -tls-cert and -tls-key are required for TLS")
	}

	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		return nil, err
	}
	return tls.Listen("tcp", addr, &tls.Config{
		MinVersion:   tls.VersionTLS12,
		Certificates: []tls.Certificate{cert},
	})
}

func (s *relayServer) handleConn(conn net.Conn) {
	remoteIP := ipFromAddr(conn.RemoteAddr())

	// Check IP ban before reading anything.
	if s.ban.isIPBanned(remoteIP) {
		slog.Warn("rejected banned IP", "remoteIP", remoteIP)
		_ = conn.Close()
		return
	}

	_ = conn.SetReadDeadline(time.Now().Add(firstMessageTimeout))
	msg, err := shared.ReadControl(conn)
	if err != nil {
		slog.Info("read hello", "remoteIP", remoteIP, "err", err)
		_ = conn.Close()
		return
	}
	_ = conn.SetReadDeadline(time.Time{})

	// Check deviceId ban.
	if msg.DeviceID != "" && s.ban.isDeviceBanned(msg.DeviceID) {
		slog.Warn("rejected banned device", "remoteIP", remoteIP, "deviceId", msg.DeviceID)
		_ = shared.WriteError(conn, "device banned")
		_ = conn.Close()
		return
	}

	if !s.authorized(msg.RelayAPIKey) {
		deviceID := msg.DeviceID
		slog.Warn("auth failed",
			"remoteIP", remoteIP,
			"deviceId", deviceID,
			"ipFailCount", s.ban.ipFailCount(remoteIP)+1,
			"deviceFailCount", s.ban.deviceFailCount(deviceID)+1,
		)

		ipBanned := s.ban.recordIPFail(remoteIP)
		if ipBanned {
			slog.Error("IP permanently banned", "remoteIP", remoteIP)
		}

		if deviceID != "" {
			deviceBanned := s.ban.recordDeviceFail(deviceID)
			if deviceBanned {
				slog.Error("deviceId permanently banned", "deviceId", deviceID)
			}
		}

		_ = shared.WriteError(conn, "unauthorized")
		_ = conn.Close()
		return
	}

	switch msg.Type {
	case shared.TypeAgentRegister:
		s.handleAgentControl(conn, msg)
	case shared.TypeClientConnect:
		s.handleClient(conn, msg)
	case shared.TypeAgentSession:
		s.handleAgentSession(conn, msg)
	default:
		slog.Warn("unknown first message type", "remoteIP", remoteIP, "type", msg.Type)
		_ = shared.WriteError(conn, "unknown first message type %q", msg.Type)
		_ = conn.Close()
	}
}

func (s *relayServer) handleAgentControl(conn net.Conn, msg shared.ControlMessage) {
	remoteIP := ipFromAddr(conn.RemoteAddr())

	if msg.DeviceID == "" {
		_ = shared.WriteError(conn, "missing deviceId")
		_ = conn.Close()
		return
	}

	agent := &agentConn{
		deviceID:     msg.DeviceID,
		conn:         conn,
		send:         make(chan shared.ControlMessage, 32),
		capabilities: msg.Capabilities,
		plugins:      msg.Plugins,
	}

	s.mu.Lock()
	if old := s.agents[msg.DeviceID]; old != nil {
		_ = old.conn.Close()
	}
	s.agents[msg.DeviceID] = agent
	s.mu.Unlock()

	slog.Info("agent online", "deviceId", msg.DeviceID, "remoteIP", remoteIP)
	if err := shared.WriteReady(conn); err != nil {
		s.removeAgent(agent)
		_ = conn.Close()
		return
	}

	agent.writeLoop()
	s.removeAgent(agent)
	_ = conn.Close()
	slog.Info("agent offline", "deviceId", msg.DeviceID)
}

func (a *agentConn) writeLoop() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case msg := <-a.send:
			if err := shared.WriteControl(a.conn, msg); err != nil {
				return
			}
		case <-ticker.C:
			if err := shared.WriteControl(a.conn, shared.ControlMessage{Type: shared.TypeHeartbeat}); err != nil {
				return
			}
		}
	}
}

func (s *relayServer) handleClient(conn net.Conn, msg shared.ControlMessage) {
	remoteIP := ipFromAddr(conn.RemoteAddr())

	if msg.DeviceID == "" || msg.SessionID == "" {
		_ = shared.WriteError(conn, "missing deviceId or sessionId")
		_ = conn.Close()
		return
	}

	agent, err := s.prepareSession(msg.DeviceID, msg.SessionID, conn)
	if err != nil {
		_ = shared.WriteError(conn, "%v", err)
		_ = conn.Close()
		return
	}

	sessionOpen := shared.ControlMessage{
		Type:       shared.TypeSessionOpen,
		DeviceID:   msg.DeviceID,
		SessionID:  msg.SessionID,
		Transports: []string{shared.TransportRelayTCP},
	}
	select {
	case agent.send <- sessionOpen:
	case <-time.After(agentSendTimeout):
		s.removePendingSession(msg.DeviceID, msg.SessionID, conn)
		slog.Warn("agent busy, session rejected", "deviceId", msg.DeviceID, "sessionId", msg.SessionID)
		_ = shared.WriteError(conn, "agent busy")
		_ = conn.Close()
		return
	}
	go s.expirePendingSession(msg.DeviceID, msg.SessionID, conn, 15*time.Second)
	slog.Info("client waiting", "deviceId", msg.DeviceID, "sessionId", msg.SessionID, "remoteIP", remoteIP)
}

func (s *relayServer) prepareSession(deviceID, sessionID string, client net.Conn) (*agentConn, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	agent := s.agents[deviceID]
	if agent == nil {
		return nil, fmt.Errorf("device %q is offline", deviceID)
	}

	key := sessionKey(deviceID, sessionID)
	if old := s.sessions[key]; old != nil {
		_ = old.client.Close()
	}
	s.sessions[key] = &pendingSession{
		deviceID:  deviceID,
		sessionID: sessionID,
		client:    client,
		createdAt: time.Now(),
	}
	return agent, nil
}

func (s *relayServer) removePendingSession(deviceID, sessionID string, client net.Conn) {
	s.mu.Lock()
	defer s.mu.Unlock()

	key := sessionKey(deviceID, sessionID)
	pending := s.sessions[key]
	if pending == nil || pending.client != client {
		return
	}
	delete(s.sessions, key)
}

func (s *relayServer) expirePendingSession(deviceID, sessionID string, client net.Conn, ttl time.Duration) {
	time.Sleep(ttl)

	s.mu.Lock()
	defer s.mu.Unlock()

	key := sessionKey(deviceID, sessionID)
	pending := s.sessions[key]
	if pending == nil || pending.client != client {
		return
	}

	delete(s.sessions, key)
	_ = shared.WriteError(client, "agent did not open session before timeout")
	_ = client.Close()
}

func (s *relayServer) handleAgentSession(conn net.Conn, msg shared.ControlMessage) {
	if msg.DeviceID == "" || msg.SessionID == "" {
		_ = shared.WriteError(conn, "missing deviceId or sessionId")
		_ = conn.Close()
		return
	}

	client, err := s.takeClient(msg.DeviceID, msg.SessionID)
	if err != nil {
		_ = shared.WriteError(conn, "%v", err)
		_ = conn.Close()
		return
	}

	if err := shared.WriteReady(client); err != nil {
		_ = client.Close()
		_ = conn.Close()
		return
	}
	if err := shared.WriteReady(conn); err != nil {
		_ = client.Close()
		_ = conn.Close()
		return
	}

	slog.Info("session paired", "deviceId", msg.DeviceID, "sessionId", msg.SessionID)
	bridge(client, conn)
	slog.Info("session closed", "deviceId", msg.DeviceID, "sessionId", msg.SessionID)
}

func (s *relayServer) takeClient(deviceID, sessionID string) (net.Conn, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	key := sessionKey(deviceID, sessionID)
	pending := s.sessions[key]
	if pending == nil {
		return nil, errors.New("client session not found")
	}
	delete(s.sessions, key)
	return pending.client, nil
}

func bridge(left, right net.Conn) {
	done := make(chan struct{}, 2)
	go copyConn(done, left, right)
	go copyConn(done, right, left)

	<-done
	_ = left.Close()
	_ = right.Close()
	<-done
}

func copyConn(done chan<- struct{}, dst, src net.Conn) {
	defer func() { done <- struct{}{} }()
	_, _ = io.Copy(dst, src)
}

func (s *relayServer) removeAgent(agent *agentConn) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.agents[agent.deviceID] == agent {
		delete(s.agents, agent.deviceID)
	}
}

func (s *relayServer) authorized(relayAPIKey string) bool {
	return s.relayAPIKey == "" || relayAPIKey == s.relayAPIKey
}

func sessionKey(deviceID, sessionID string) string {
	return deviceID + "\x00" + sessionID
}

func ipFromAddr(addr net.Addr) string {
	host, _, err := net.SplitHostPort(addr.String())
	if err != nil {
		return addr.String()
	}
	return host
}
