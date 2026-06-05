use anyhow::Context;

use crate::api::TerminalProfile;
use crate::relay::connect_controller_stream;
use crate::ssh::{RemoteShell, ShellInput, SshClientConfig, open_remote_shell};

#[derive(Default)]
pub struct ControllerRuntime;

#[derive(Debug, Clone, Copy)]
pub struct TerminalResize {
    pub cols: u16,
    pub rows: u16,
    pub pixel_width: u16,
    pub pixel_height: u16,
}

pub struct TerminalSession {
    shell: RemoteShell,
}

impl ControllerRuntime {
    pub fn new() -> Self {
        Self
    }

    pub async fn open_terminal(&self, profile: TerminalProfile) -> anyhow::Result<TerminalSession> {
        let relay_stream = connect_controller_stream(&profile).await?;
        let shell = open_remote_shell(
            relay_stream,
            SshClientConfig {
                username: profile.username.clone(),
                password: profile.token.clone(),
            },
            TerminalResize::default(),
        )
        .await
        .with_context(|| format!("failed to open {}", Self::describe_target(&profile)))?;

        Ok(TerminalSession { shell })
    }

    pub fn describe_target(profile: &TerminalProfile) -> String {
        format!(
            "{}:{} -> {}:{}",
            profile.relay_host, profile.relay_port, profile.device_id, profile.session_id
        )
    }
}

impl TerminalSession {
    pub async fn write(&self, data: Vec<u8>) -> anyhow::Result<()> {
        self.shell.send(ShellInput::Data(data)).await
    }

    pub async fn resize(&self, resize: TerminalResize) -> anyhow::Result<()> {
        self.shell.send(ShellInput::Resize(resize)).await
    }

    pub async fn next_output(&self) -> Option<Vec<u8>> {
        self.shell.next_output().await
    }

    pub async fn close(&self) -> anyhow::Result<()> {
        self.shell.send(ShellInput::Close).await
    }
}

impl Default for TerminalResize {
    fn default() -> Self {
        Self {
            cols: 80,
            rows: 24,
            pixel_width: 0,
            pixel_height: 0,
        }
    }
}
