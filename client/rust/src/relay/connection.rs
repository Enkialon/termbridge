use std::time::Duration;

use anyhow::{Context, bail};
use serde_json::Value;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::time::timeout;

use crate::agent::AgentConfig;
use crate::api::TerminalProfile;
use crate::tunnel::Tunnel;

use super::ControlMessage;

const RELAY_CONNECT_TIMEOUT: Duration = Duration::from_secs(12);

pub async fn connect_controller_tunnel(profile: &TerminalProfile) -> anyhow::Result<Tunnel> {
    let stream = connect_controller_stream(profile).await?;
    Ok(Tunnel::relay_tcp(stream))
}

pub async fn connect_controller_stream(profile: &TerminalProfile) -> anyhow::Result<TcpStream> {
    if profile.use_tls {
        bail!("TLS relay transport is not wired in the Rust core yet");
    }

    let addr = format!("{}:{}", profile.relay_host, profile.relay_port);
    let mut stream = timeout(RELAY_CONNECT_TIMEOUT, TcpStream::connect(&addr))
        .await
        .context("timed out connecting to relay")?
        .with_context(|| format!("failed to connect to relay {addr}"))?;

    let control = ControlMessage::client_connect(profile).encode_line()?;
    stream
        .write_all(&control)
        .await
        .context("failed to send relay client connect message")?;
    stream
        .flush()
        .await
        .context("failed to flush relay control")?;

    let line = read_control_line(&mut stream).await?;
    let decoded: Value = serde_json::from_slice(&line).context("invalid relay response JSON")?;
    let message_type = decoded
        .get("type")
        .and_then(Value::as_str)
        .context("relay response is missing type")?;

    match message_type {
        "ready" => Ok(stream),
        "error" => {
            let message = decoded
                .get("message")
                .and_then(Value::as_str)
                .unwrap_or("relay rejected controller connection");
            bail!("{message}")
        }
        other => bail!("unexpected relay response: {other}"),
    }
}

pub async fn connect_agent_tunnel(config: &AgentConfig) -> anyhow::Result<Tunnel> {
    let stream = connect_agent_stream(config).await?;
    Ok(Tunnel::relay_tcp(stream))
}

pub async fn connect_agent_session_tunnel(
    config: &AgentConfig,
    session_id: String,
) -> anyhow::Result<Tunnel> {
    let stream = connect_agent_session_stream(config, session_id).await?;
    Ok(Tunnel::relay_tcp(stream))
}

pub async fn connect_agent_stream(config: &AgentConfig) -> anyhow::Result<TcpStream> {
    if config.use_tls {
        bail!("TLS relay transport is not wired in the Rust core yet");
    }

    let addr = format!("{}:{}", config.relay_host, config.relay_port);
    let mut stream = timeout(RELAY_CONNECT_TIMEOUT, TcpStream::connect(&addr))
        .await
        .context("timed out connecting to relay")?
        .with_context(|| format!("failed to connect to relay {addr}"))?;

    let control = ControlMessage::agent_register(config).encode_line()?;
    stream
        .write_all(&control)
        .await
        .context("failed to send relay agent register message")?;
    stream
        .flush()
        .await
        .context("failed to flush relay control")?;

    let line = read_control_line(&mut stream).await?;
    let decoded: Value = serde_json::from_slice(&line).context("invalid relay response JSON")?;
    let message_type = decoded
        .get("type")
        .and_then(Value::as_str)
        .context("relay response is missing type")?;

    match message_type {
        "ready" => Ok(stream),
        "error" => {
            let message = decoded
                .get("message")
                .and_then(Value::as_str)
                .unwrap_or("relay rejected agent registration");
            bail!("{message}")
        }
        other => bail!("unexpected relay response: {other}"),
    }
}

pub async fn connect_agent_session_stream(
    config: &AgentConfig,
    session_id: String,
) -> anyhow::Result<TcpStream> {
    if config.use_tls {
        bail!("TLS relay transport is not wired in the Rust core yet");
    }

    let addr = format!("{}:{}", config.relay_host, config.relay_port);
    let mut stream = timeout(RELAY_CONNECT_TIMEOUT, TcpStream::connect(&addr))
        .await
        .context("timed out connecting to relay")?
        .with_context(|| format!("failed to connect to relay {addr}"))?;

    let control = ControlMessage::agent_session(config, session_id).encode_line()?;
    stream
        .write_all(&control)
        .await
        .context("failed to send relay agent session message")?;
    stream
        .flush()
        .await
        .context("failed to flush relay agent session control")?;

    let line = read_control_line(&mut stream).await?;
    let decoded: Value = serde_json::from_slice(&line).context("invalid relay response JSON")?;
    let message_type = decoded
        .get("type")
        .and_then(Value::as_str)
        .context("relay response is missing type")?;

    match message_type {
        "ready" => Ok(stream),
        "error" => {
            let message = decoded
                .get("message")
                .and_then(Value::as_str)
                .unwrap_or("relay rejected agent session");
            bail!("{message}")
        }
        other => bail!("unexpected relay response: {other}"),
    }
}

async fn read_control_line(stream: &mut TcpStream) -> anyhow::Result<Vec<u8>> {
    let mut line = Vec::with_capacity(128);
    loop {
        let mut byte = [0_u8; 1];
        let read = timeout(RELAY_CONNECT_TIMEOUT, stream.read(&mut byte))
            .await
            .context("timed out waiting for relay ready")?
            .context("failed to read relay ready")?;
        if read == 0 {
            bail!("relay closed before ready");
        }
        if byte[0] == b'\n' {
            return Ok(line);
        }
        line.push(byte[0]);
        if line.len() > 16 * 1024 {
            bail!("relay control line is too large");
        }
    }
}

pub async fn read_control_line_blocking(stream: &mut TcpStream) -> anyhow::Result<Vec<u8>> {
    let mut line = Vec::with_capacity(128);
    loop {
        let mut byte = [0_u8; 1];
        let read = stream
            .read(&mut byte)
            .await
            .context("failed to read relay control")?;
        if read == 0 {
            bail!("relay control connection closed");
        }
        if byte[0] == b'\n' {
            return Ok(line);
        }
        line.push(byte[0]);
        if line.len() > 16 * 1024 {
            bail!("relay control line is too large");
        }
    }
}
