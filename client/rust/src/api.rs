use serde::{Deserialize, Serialize};

use crate::agent::{AgentConfig, AgentRuntime};
use crate::controller::{ControllerRuntime, TerminalSession};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TerminalProfile {
    pub relay_host: String,
    pub relay_port: u16,
    pub device_id: String,
    pub session_id: String,
    pub token: String,
    pub username: String,
    pub use_tls: bool,
    pub allow_bad_certificate: bool,
}

pub struct ClientCore {
    agent: AgentRuntime,
    controller: ControllerRuntime,
}

impl ClientCore {
    pub fn new() -> Self {
        Self {
            agent: AgentRuntime::new(),
            controller: ControllerRuntime::new(),
        }
    }

    pub fn agent(&self) -> &AgentRuntime {
        &self.agent
    }

    pub fn controller(&self) -> &ControllerRuntime {
        &self.controller
    }

    pub async fn open_terminal(&self, profile: TerminalProfile) -> anyhow::Result<TerminalSession> {
        self.controller.open_terminal(profile).await
    }
}

impl Default for ClientCore {
    fn default() -> Self {
        Self::new()
    }
}

pub fn create_agent_config(
    relay_host: String,
    relay_port: u16,
    device_id: String,
    token: String,
    shell: String,
    use_tls: bool,
    allow_bad_certificate: bool,
) -> AgentConfig {
    AgentConfig {
        relay_host,
        relay_port,
        device_id,
        token,
        shell,
        use_tls,
        allow_bad_certificate,
    }
}
