use serde::{Deserialize, Serialize};

use crate::agent::AgentConfig;
use crate::api::TerminalProfile;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MessageType {
    #[serde(rename = "agent.register")]
    AgentRegister,
    #[serde(rename = "agent.session")]
    AgentSession,
    #[serde(rename = "client.connect")]
    ClientConnect,
    #[serde(rename = "session.open")]
    SessionOpen,
    Ready,
    Error,
    Heartbeat,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ControlMessage {
    #[serde(rename = "type")]
    pub message_type: MessageType,
    #[serde(rename = "deviceId", skip_serializing_if = "Option::is_none")]
    pub device_id: Option<String>,
    #[serde(rename = "sessionId", skip_serializing_if = "Option::is_none")]
    pub session_id: Option<String>,
    #[serde(rename = "relayApiKey", skip_serializing_if = "Option::is_none")]
    pub relay_api_key: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
}

impl ControlMessage {
    pub fn agent_register(config: &AgentConfig) -> Self {
        Self {
            message_type: MessageType::AgentRegister,
            device_id: Some(config.device_id.clone()),
            session_id: None,
            relay_api_key: Some(config.relay_api_key.clone()),
            message: None,
        }
    }

    pub fn client_connect(profile: &TerminalProfile) -> Self {
        Self {
            message_type: MessageType::ClientConnect,
            device_id: Some(profile.device_id.clone()),
            session_id: Some(profile.session_id.clone()),
            relay_api_key: Some(profile.relay_api_key.clone()),
            message: None,
        }
    }

    pub fn encode_line(&self) -> anyhow::Result<Vec<u8>> {
        let mut encoded = serde_json::to_vec(self)?;
        encoded.push(b'\n');
        Ok(encoded)
    }
}
