use serde::{Deserialize, Serialize};
use tokio::sync::{Mutex, oneshot};
use tokio::task::JoinHandle;

use std::sync::Arc;

use crate::relay::connect_agent_stream;
use crate::ssh::{SshServerConfig, run_pty_ssh_server};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentConfig {
    pub relay_host: String,
    pub relay_port: u16,
    pub device_id: String,
    pub token: String,
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

    pub async fn stop(&self) -> anyhow::Result<()> {
        if let Some(task) = self.task.lock().await.take() {
            let _ = task.stop.send(());
            let _ = task.handle.await;
        }
        *self.status.lock().await = AgentStatus::Stopped;
        Ok(())
    }
}

async fn run_agent_once(
    config: AgentConfig,
    stop: oneshot::Receiver<()>,
    status: Arc<Mutex<AgentStatus>>,
) -> anyhow::Result<()> {
    let stream = connect_agent_stream(&config).await?;
    *status.lock().await = AgentStatus::Online;

    tokio::select! {
        result = run_pty_ssh_server(
            stream,
            SshServerConfig {
                password: Some(config.token),
                shell: Some(config.shell),
            },
        ) => {
            result?;
        }
        _ = stop => {}
    }

    *status.lock().await = AgentStatus::Stopped;
    Ok(())
}
