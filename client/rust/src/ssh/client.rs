use std::sync::Arc;
use std::time::Duration;

use anyhow::{Context, bail};
use russh::{ChannelMsg, Disconnect, client};
use tokio::io::{AsyncRead, AsyncWrite};
use tokio::sync::{Mutex, mpsc};

use crate::controller::TerminalResize;

#[derive(Debug, Clone)]
pub struct SshClientConfig {
    pub username: String,
    pub password: String,
}

pub struct RemoteShell {
    input: mpsc::Sender<ShellInput>,
    output: Arc<Mutex<mpsc::Receiver<Vec<u8>>>>,
}

#[derive(Debug)]
pub enum ShellInput {
    Data(Vec<u8>),
    Resize(TerminalResize),
    Close,
}

struct Client;

impl client::Handler for Client {
    type Error = russh::Error;

    async fn check_server_key(
        &mut self,
        _server_public_key: &russh::keys::ssh_key::PublicKey,
    ) -> Result<bool, Self::Error> {
        Ok(true)
    }
}

pub async fn open_remote_shell<S>(
    stream: S,
    config: SshClientConfig,
    size: TerminalResize,
) -> anyhow::Result<RemoteShell>
where
    S: AsyncRead + AsyncWrite + Unpin + Send + 'static,
{
    let ssh_config = Arc::new(client::Config {
        inactivity_timeout: Some(Duration::from_secs(3600)),
        ..Default::default()
    });

    let mut session = client::connect_stream(ssh_config, stream, Client)
        .await
        .context("failed to start SSH client over relay stream")?;

    let auth = session
        .authenticate_password(config.username, config.password)
        .await
        .context("SSH password authentication failed")?;
    if !auth.success() {
        bail!("SSH password authentication rejected");
    }

    let mut channel = session
        .channel_open_session()
        .await
        .context("failed to open SSH session channel")?;
    channel
        .request_pty(
            false,
            "xterm-256color",
            size.cols as u32,
            size.rows as u32,
            size.pixel_width as u32,
            size.pixel_height as u32,
            &[],
        )
        .await
        .context("failed to request SSH PTY")?;
    channel
        .request_shell(false)
        .await
        .context("failed to request SSH shell")?;

    let (input_tx, mut input_rx) = mpsc::channel::<ShellInput>(128);
    let (output_tx, output_rx) = mpsc::channel::<Vec<u8>>(128);

    tokio::spawn(async move {
        loop {
            tokio::select! {
                Some(input) = input_rx.recv() => {
                    match input {
                        ShellInput::Data(data) => {
                            if channel.data(data.as_slice()).await.is_err() {
                                break;
                            }
                        }
                        ShellInput::Resize(size) => {
                            if channel
                                .window_change(
                                    size.cols as u32,
                                    size.rows as u32,
                                    size.pixel_width as u32,
                                    size.pixel_height as u32,
                                )
                                .await
                                .is_err()
                            {
                                break;
                            }
                        }
                        ShellInput::Close => {
                            let _ = channel.eof().await;
                            break;
                        }
                    }
                }
                Some(message) = channel.wait() => {
                    match message {
                        ChannelMsg::Data { data } => {
                            if output_tx.send(data.to_vec()).await.is_err() {
                                break;
                            }
                        }
                        ChannelMsg::ExtendedData { data, .. } => {
                            if output_tx.send(data.to_vec()).await.is_err() {
                                break;
                            }
                        }
                        ChannelMsg::ExitStatus { .. } | ChannelMsg::Eof | ChannelMsg::Close => {
                            break;
                        }
                        _ => {}
                    }
                }
                else => break,
            }
        }

        let _ = channel.close().await;
        let _ = session
            .disconnect(Disconnect::ByApplication, "terminal closed", "en")
            .await;
    });

    Ok(RemoteShell {
        input: input_tx,
        output: Arc::new(Mutex::new(output_rx)),
    })
}

impl RemoteShell {
    pub async fn send(&self, input: ShellInput) -> anyhow::Result<()> {
        self.input
            .send(input)
            .await
            .context("SSH shell task is closed")
    }

    pub async fn next_output(&self) -> Option<Vec<u8>> {
        self.output.lock().await.recv().await
    }
}
