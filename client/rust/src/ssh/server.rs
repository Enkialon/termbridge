use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use anyhow::Context;
use portable_pty::PtySize;
use russh::keys::{Algorithm, PrivateKey};
use russh::server::{self, Msg, Session};
use russh::{Channel, ChannelId, CryptoVec};
use tokio::io::{AsyncRead, AsyncWrite};

use crate::pty::{InteractivePty, default_shell, spawn_interactive_pty};

#[derive(Debug, Clone)]
pub struct SshServerConfig {
    pub password: Option<String>,
    pub shell: Option<String>,
}

#[derive(Clone)]
struct PtyServer {
    password: Option<String>,
    shell: String,
    sizes: Arc<Mutex<HashMap<ChannelId, PtySize>>>,
    ptys: Arc<Mutex<HashMap<ChannelId, InteractivePty>>>,
}

pub async fn run_pty_ssh_server<S>(stream: S, config: SshServerConfig) -> anyhow::Result<()>
where
    S: AsyncRead + AsyncWrite + Unpin + Send + 'static,
{
    let server_config = Arc::new(server::Config {
        inactivity_timeout: Some(Duration::from_secs(3600)),
        auth_rejection_time: Duration::from_millis(300),
        auth_rejection_time_initial: Some(Duration::from_millis(0)),
        keys: vec![
            PrivateKey::random(&mut rand::rngs::OsRng, Algorithm::Ed25519)
                .context("failed to generate SSH host key")?,
        ],
        ..Default::default()
    });

    let handler = PtyServer {
        password: config.password,
        shell: config.shell.unwrap_or_else(default_shell),
        sizes: Arc::new(Mutex::new(HashMap::new())),
        ptys: Arc::new(Mutex::new(HashMap::new())),
    };

    let session = server::run_stream(server_config, stream, handler)
        .await
        .context("SSH server over relay stream failed")?;
    session
        .await
        .context("SSH server over relay stream failed")?;
    Ok(())
}

impl server::Handler for PtyServer {
    type Error = russh::Error;

    async fn auth_password(
        &mut self,
        _user: &str,
        password: &str,
    ) -> Result<server::Auth, Self::Error> {
        if self
            .password
            .as_deref()
            .is_none_or(|expected| expected == password)
        {
            Ok(server::Auth::Accept)
        } else {
            Ok(server::Auth::reject())
        }
    }

    async fn channel_open_session(
        &mut self,
        _channel: Channel<Msg>,
        _session: &mut Session,
    ) -> Result<bool, Self::Error> {
        Ok(true)
    }

    async fn pty_request(
        &mut self,
        channel: ChannelId,
        _term: &str,
        col_width: u32,
        row_height: u32,
        pix_width: u32,
        pix_height: u32,
        _modes: &[(russh::Pty, u32)],
        session: &mut Session,
    ) -> Result<(), Self::Error> {
        let size = PtySize {
            cols: col_width as u16,
            rows: row_height as u16,
            pixel_width: pix_width as u16,
            pixel_height: pix_height as u16,
        };
        self.sizes
            .lock()
            .expect("sizes mutex poisoned")
            .insert(channel, size);
        let _ = session.channel_success(channel);
        Ok(())
    }

    async fn shell_request(
        &mut self,
        channel: ChannelId,
        session: &mut Session,
    ) -> Result<(), Self::Error> {
        let size = self
            .sizes
            .lock()
            .expect("sizes mutex poisoned")
            .get(&channel)
            .copied()
            .unwrap_or_default();
        let (pty, output_rx) = spawn_interactive_pty(&self.shell, size).map_err(|_| {
            russh::Error::ChannelOpenFailure(russh::ChannelOpenFailure::ResourceShortage)
        })?;

        self.ptys
            .lock()
            .expect("ptys mutex poisoned")
            .insert(channel, pty);

        let handle = session.handle();
        let runtime = tokio::runtime::Handle::current();
        std::thread::spawn(move || {
            while let Ok(output) = output_rx.recv() {
                let handle = handle.clone();
                runtime.spawn(async move {
                    let _ = handle.data(channel, CryptoVec::from_slice(&output)).await;
                });
            }
        });

        let _ = session.channel_success(channel);
        Ok(())
    }

    async fn data(
        &mut self,
        channel: ChannelId,
        data: &[u8],
        _session: &mut Session,
    ) -> Result<(), Self::Error> {
        if let Some(pty) = self.ptys.lock().expect("ptys mutex poisoned").get(&channel) {
            let _ = pty.write(data);
        }
        Ok(())
    }

    async fn window_change_request(
        &mut self,
        channel: ChannelId,
        col_width: u32,
        row_height: u32,
        pix_width: u32,
        pix_height: u32,
        _session: &mut Session,
    ) -> Result<(), Self::Error> {
        let size = PtySize {
            cols: col_width as u16,
            rows: row_height as u16,
            pixel_width: pix_width as u16,
            pixel_height: pix_height as u16,
        };
        if let Some(pty) = self.ptys.lock().expect("ptys mutex poisoned").get(&channel) {
            let _ = pty.resize(size);
        }
        Ok(())
    }

    async fn channel_close(
        &mut self,
        channel: ChannelId,
        _session: &mut Session,
    ) -> Result<(), Self::Error> {
        if let Some(pty) = self
            .ptys
            .lock()
            .expect("ptys mutex poisoned")
            .remove(&channel)
        {
            let _ = pty.close();
        }
        self.sizes
            .lock()
            .expect("sizes mutex poisoned")
            .remove(&channel);
        Ok(())
    }
}
