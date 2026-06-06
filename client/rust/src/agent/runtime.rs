use serde::{Deserialize, Serialize};
use tokio::sync::{Mutex, oneshot};
use tokio::task::JoinHandle;

use std::sync::Arc;

#[cfg(not(target_os = "android"))]
use crate::relay::{
    MessageType, connect_agent_session_tunnel, connect_agent_stream, read_control_line_blocking,
};
#[cfg(not(target_os = "android"))]
use crate::ssh::{SshServerConfig, run_pty_ssh_server};
#[cfg(not(target_os = "android"))]
use anyhow::{Context, bail};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentConfig {
    pub relay_host: String,
    pub relay_port: u16,
    pub device_id: String,
    pub relay_api_key: String,
    pub password: String,
    pub shell: String,
    pub use_tls: bool,
    pub allow_bad_certificate: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AgentStatus {
    Stopped,
    Connecting,
    Online,
    Error { message: String },
}

pub struct AgentRuntime {
    status: Arc<Mutex<AgentStatus>>,
    task: Arc<Mutex<Option<AgentTask>>>,
}

impl Default for AgentRuntime {
    fn default() -> Self {
        Self::new()
    }
}

struct AgentTask {
    stop: oneshot::Sender<()>,
    handle: JoinHandle<()>,
}

impl AgentRuntime {
    pub fn new() -> Self {
        Self {
            status: Arc::new(Mutex::new(AgentStatus::Stopped)),
            task: Arc::new(Mutex::new(None)),
        }
    }

    pub async fn status(&self) -> AgentStatus {
        self.status.lock().await.clone()
    }

    pub async fn start(&self, config: AgentConfig) -> anyhow::Result<()> {
        #[cfg(target_os = "android")]
        {
            let _ = config;
            *self.status.lock().await = AgentStatus::Error {
                message: "agent mode is not supported on Android".to_string(),
            };
            anyhow::bail!("agent mode is not supported on Android");
        }

        #[cfg(not(target_os = "android"))]
        {
            self.stop().await?;

            *self.status.lock().await = AgentStatus::Connecting;

            let status = self.status.clone();
            let (stop_tx, stop_rx) = oneshot::channel::<()>();
            let handle = tokio::spawn(async move {
                let result = run_agent_once(config, stop_rx, status.clone()).await;
                if let Err(error) = result {
                    *status.lock().await = AgentStatus::Error {
                        message: error.to_string(),
                    };
                }
            });

            *self.task.lock().await = Some(AgentTask {
                stop: stop_tx,
                handle,
            });
            Ok(())
        }
    }

    pub async fn stop(&self) -> anyhow::Result<()> {
        if let Some(task) = self.task.lock().await.take() {
            let _ = task.stop.send(());
            let _ = task.handle.await;
        }
        *self.status.lock().await = AgentStatus::Stopped;
        Ok(())
    }
}

#[cfg(not(target_os = "android"))]
async fn run_agent_once(
    config: AgentConfig,
    mut stop: oneshot::Receiver<()>,
    status: Arc<Mutex<AgentStatus>>,
) -> anyhow::Result<()> {
    let mut control = connect_agent_stream(&config).await?;
    *status.lock().await = AgentStatus::Online;
    let mut sessions = Vec::<JoinHandle<anyhow::Result<()>>>::new();

    loop {
        tokio::select! {
            line = read_control_line_blocking(&mut control) => {
                let line = line?;
                let message: crate::relay::ControlMessage =
                    serde_json::from_slice(&line).context("invalid relay control JSON")?;
                match message.message_type {
                    MessageType::SessionOpen => {
                        let session_id = message.session_id.context("session.open missing sessionId")?;
                        let session_config = config.clone();
                        sessions.push(tokio::spawn(async move {
                            run_agent_session(session_config, session_id).await
                        }));
                    }
                    MessageType::Heartbeat => {
                        sessions.retain(|session| !session.is_finished());
                    }
                    MessageType::Error => {
                        let message = message.message.unwrap_or_else(|| "relay returned error".to_string());
                        bail!("{message}");
                    }
                    other => bail!("unexpected relay control message: {other:?}"),
                }
            }
            _ = &mut stop => {
                for session in sessions {
                    session.abort();
                }
                break;
            }
        }
    }

    *status.lock().await = AgentStatus::Stopped;
    Ok(())
}

#[cfg(not(target_os = "android"))]
async fn run_agent_session(config: AgentConfig, session_id: String) -> anyhow::Result<()> {
    let tunnel = connect_agent_session_tunnel(&config, session_id).await?;
    run_pty_ssh_server(
        tunnel,
        SshServerConfig {
            password: if config.password.is_empty() {
                None
            } else {
                Some(config.password)
            },
            shell: Some(config.shell),
        },
    )
    .await
}
