package main

import (
	"crypto/tls"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"sync"
	"time"

	shared "th/shared/protocol"
)

type relayServer struct {
	token string

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
	token := flag.String("token", "", "shared relay token; empty disables relay auth")
	tlsCert := flag.String("tls-cert", "", "TLS certificate file; requires -tls-key")
	tlsKey := flag.String("tls-key", "", "TLS private key file; requires -tls-cert")
	flag.Parse()

	s := &relayServer{
		token:    *token,
		agents:   make(map[string]*agentConn),
		sessions: make(map[string]*pendingSession),
	}

	ln, err := listen(*addr, *tlsCert, *tlsKey)
	if err != nil {
		log.Fatal(err)
	}
	defer ln.Close()

	mode := "tcp"
	if *tlsCert != "" || *tlsKey != "" {
		mode = "tls"
	}
	log.Printf("relay listening on %s mode=%s", *addr, mode)

	for {
		conn, err := ln.Accept()
		if err != nil {
			log.Printf("accept: %v", err)
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
	msg, err := shared.ReadControl(conn)
	if err != nil {
		log.Printf("read hello from %s: %v", conn.RemoteAddr(), err)
		_ = conn.Close()
		return
	}

	if !s.authorized(msg.Token) {
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
		_ = shared.WriteError(conn, "unknown first message type %q", msg.Type)
		_ = conn.Close()
	}
}

func (s *relayServer) handleAgentControl(conn net.Conn, msg shared.ControlMessage) {
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

	log.Printf("agent online device=%s", msg.DeviceID)
	if err := shared.WriteReady(conn); err != nil {
		s.removeAgent(agent)
		_ = conn.Close()
		return
	}

	agent.writeLoop()
	s.removeAgent(agent)
	_ = conn.Close()
	log.Printf("agent offline device=%s", msg.DeviceID)
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

	agent.send <- shared.ControlMessage{
		Type:       shared.TypeSessionOpen,
		DeviceID:   msg.DeviceID,
		SessionID:  msg.SessionID,
		Transports: []string{shared.TransportRelayTCP},
	}
	go s.expirePendingSession(msg.DeviceID, msg.SessionID, conn, 15*time.Second)
	log.Printf("client waiting device=%s session=%s", msg.DeviceID, msg.SessionID)
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

	log.Printf("session paired device=%s session=%s", msg.DeviceID, msg.SessionID)
	bridge(client, conn)
	log.Printf("session closed device=%s session=%s", msg.DeviceID, msg.SessionID)
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

func (s *relayServer) authorized(token string) bool {
	return s.token == "" || token == s.token
}

func sessionKey(deviceID, sessionID string) string {
	return deviceID + "\x00" + sessionID
}
