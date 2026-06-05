use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::{Arc, OnceLock};

use tokio::sync::Mutex;

use crate::agent::{AgentConfig, AgentStatus};
use crate::api::{ClientCore, TerminalProfile};
use crate::controller::TerminalResize;

static BRIDGE: OnceLock<BridgeState> = OnceLock::new();

struct BridgeState {
    core: ClientCore,
    next_terminal_id: AtomicU32,
    terminals: Mutex<HashMap<u32, Arc<crate::controller::TerminalSession>>>,
}

fn bridge() -> &'static BridgeState {
    BRIDGE.get_or_init(|| BridgeState {
        core: ClientCore::new(),
        next_terminal_id: AtomicU32::new(1),
        terminals: Mutex::new(HashMap::new()),
    })
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    let _ = bridge();
}

#[derive(Debug, Clone)]
pub struct FrbTerminalProfile {
    pub relay_host: String,
    pub relay_port: u16,
    pub device_id: String,
    pub session_id: String,
    pub token: String,
    pub username: String,
    pub use_tls: bool,
    pub allow_bad_certificate: bool,
}

#[derive(Debug, Clone)]
pub struct FrbAgentConfig {
    pub relay_host: String,
    pub relay_port: u16,
    pub device_id: String,
    pub token: String,
    pub shell: String,
    pub use_tls: bool,
    pub allow_bad_certificate: bool,
}

#[derive(Debug, Clone)]
pub struct FrbAgentStatus {
    pub kind: String,
    pub message: Option<String>,
}

pub async fn start_agent(config: FrbAgentConfig) -> anyhow::Result<()> {
    bridge().core.agent().start(config.into()).await
}

pub async fn stop_agent() -> anyhow::Result<()> {
    bridge().core.agent().stop().await
}

pub async fn agent_status() -> FrbAgentStatus {
    bridge().core.agent().status().await.into()
}

pub async fn open_terminal(profile: FrbTerminalProfile) -> anyhow::Result<u32> {
    let session = bridge().core.open_terminal(profile.into()).await?;
    let id = bridge().next_terminal_id.fetch_add(1, Ordering::Relaxed);
    bridge()
        .terminals
        .lock()
        .await
        .insert(id, Arc::new(session));
    Ok(id)
}

pub async fn terminal_write(id: u32, data: Vec<u8>) -> anyhow::Result<()> {
    let session = bridge()
        .terminals
        .lock()
        .await
        .get(&id)
        .cloned()
        .ok_or_else(|| anyhow::anyhow!("terminal session {id} not found"))?;
    session.write(data).await
}

pub async fn terminal_resize(
    id: u32,
    cols: u16,
    rows: u16,
    pixel_width: u16,
    pixel_height: u16,
) -> anyhow::Result<()> {
    let session = bridge()
        .terminals
        .lock()
        .await
        .get(&id)
        .cloned()
        .ok_or_else(|| anyhow::anyhow!("terminal session {id} not found"))?;
    session
        .resize(TerminalResize {
            cols,
            rows,
            pixel_width,
            pixel_height,
        })
        .await
}

pub async fn terminal_next_output(id: u32) -> anyhow::Result<Option<Vec<u8>>> {
    let session = bridge()
        .terminals
        .lock()
        .await
        .get(&id)
        .cloned()
        .ok_or_else(|| anyhow::anyhow!("terminal session {id} not found"))?;
    Ok(session.next_output().await)
}

pub async fn terminal_close(id: u32) -> anyhow::Result<()> {
    let session = bridge().terminals.lock().await.remove(&id);
    if let Some(session) = session {
        session.close().await?;
    }
    Ok(())
}

impl From<FrbTerminalProfile> for TerminalProfile {
    fn from(value: FrbTerminalProfile) -> Self {
        Self {
            relay_host: value.relay_host,
            relay_port: value.relay_port,
            device_id: value.device_id,
            session_id: value.session_id,
            token: value.token,
            username: value.username,
            use_tls: value.use_tls,
            allow_bad_certificate: value.allow_bad_certificate,
        }
    }
}

impl From<FrbAgentConfig> for AgentConfig {
    fn from(value: FrbAgentConfig) -> Self {
        Self {
            relay_host: value.relay_host,
            relay_port: value.relay_port,
            device_id: value.device_id,
            token: value.token,
            shell: value.shell,
            use_tls: value.use_tls,
            allow_bad_certificate: value.allow_bad_certificate,
        }
    }
}

impl From<AgentStatus> for FrbAgentStatus {
    fn from(value: AgentStatus) -> Self {
        match value {
            AgentStatus::Stopped => Self {
                kind: "stopped".to_string(),
                message: None,
            },
            AgentStatus::Connecting => Self {
                kind: "connecting".to_string(),
                message: None,
            },
            AgentStatus::Online => Self {
                kind: "online".to_string(),
                message: None,
            },
            AgentStatus::Error { message } => Self {
                kind: "error".to_string(),
                message: Some(message),
            },
        }
    }
}
