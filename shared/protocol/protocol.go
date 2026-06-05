package protocol

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
)

const (
	TypeAgentRegister = "agent.register"
	TypeAgentSession  = "agent.session"
	TypeClientConnect = "client.connect"
	TypeSessionOpen   = "session.open"
	TypeReady         = "ready"
	TypeError         = "error"
	TypeHeartbeat     = "heartbeat"

	TransportRelayTCP = "relay-tcp"

	CapabilityTerminal = "terminal"
	CapabilityPlugins  = "plugins"

	PluginChannelPrefix       = "mrt.plugin."
	PluginChannelCapabilities = "mrt.plugin.capabilities@v1"
	PluginChannelGitDiff      = "mrt.plugin.git-diff@v1"
)

type ControlMessage struct {
	Type         string       `json:"type"`
	DeviceID     string       `json:"deviceId,omitempty"`
	SessionID    string       `json:"sessionId,omitempty"`
	Token        string       `json:"token,omitempty"`
	Transports   []string     `json:"transports,omitempty"`
	Capabilities []string     `json:"capabilities,omitempty"`
	Plugins      []PluginInfo `json:"plugins,omitempty"`
	Message      string       `json:"message,omitempty"`
}

type PluginInfo struct {
	Name        string `json:"name"`
	ChannelType string `json:"channelType"`
	Version     string `json:"version"`
}

func ReadControl(r io.Reader) (ControlMessage, error) {
	line := make([]byte, 0, 1024)
	buf := make([]byte, 1)

	for {
		n, err := r.Read(buf)
		if n > 0 {
			if buf[0] == '\n' {
				break
			}
			line = append(line, buf[0])
			if len(line) > 64*1024 {
				return ControlMessage{}, errors.New("control message too large")
			}
		}
		if err != nil {
			return ControlMessage{}, err
		}
	}

	var msg ControlMessage
	if err := json.Unmarshal(line, &msg); err != nil {
		return ControlMessage{}, err
	}
	if msg.Type == "" {
		return ControlMessage{}, errors.New("missing control message type")
	}
	return msg, nil
}

func WriteControl(w io.Writer, msg ControlMessage) error {
	data, err := json.Marshal(msg)
	if err != nil {
		return err
	}
	data = append(data, '\n')
	_, err = w.Write(data)
	return err
}

func WriteReady(w io.Writer) error {
	return WriteControl(w, ControlMessage{Type: TypeReady})
}

func WriteError(w io.Writer, format string, args ...any) error {
	return WriteControl(w, ControlMessage{
		Type:    TypeError,
		Message: fmt.Sprintf(format, args...),
	})
}
