use std::sync::Arc;
use std::time::Duration;

use anyhow::{Context, bail};
use serde_json::Value;
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::time::timeout;
use tokio_rustls::TlsConnector;
use tokio_rustls::rustls::client::danger::{
    HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier,
};
use tokio_rustls::rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use tokio_rustls::rustls::{ClientConfig, DigitallySignedStruct, RootCertStore, SignatureScheme};
use webpki_roots::TLS_SERVER_ROOTS;

use crate::agent::AgentConfig;
use crate::api::TerminalProfile;
use crate::tunnel::{RelayStream, Tunnel};

use super::ControlMessage;

const RELAY_CONNECT_TIMEOUT: Duration = Duration::from_secs(12);

pub async fn connect_controller_tunnel(profile: &TerminalProfile) -> anyhow::Result<Tunnel> {
    let stream = connect_controller_stream(profile).await?;
    Ok(Tunnel::relay_tcp(stream))
}

pub async fn connect_controller_stream(profile: &TerminalProfile) -> anyhow::Result<RelayStream> {
    let mut stream = connect_relay_stream(
        &profile.relay_host,
        profile.relay_port,
        profile.use_tls,
        profile.allow_bad_certificate,
    )
    .await?;

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

pub async fn connect_agent_stream(config: &AgentConfig) -> anyhow::Result<RelayStream> {
    let mut stream = connect_relay_stream(
        &config.relay_host,
        config.relay_port,
        config.use_tls,
        config.allow_bad_certificate,
    )
    .await?;

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
) -> anyhow::Result<RelayStream> {
    let mut stream = connect_relay_stream(
        &config.relay_host,
        config.relay_port,
        config.use_tls,
        config.allow_bad_certificate,
    )
    .await?;

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

async fn connect_relay_stream(
    host: &str,
    port: u16,
    use_tls: bool,
    allow_bad_certificate: bool,
) -> anyhow::Result<RelayStream> {
    let addr = format!("{host}:{port}");
    let stream = timeout(RELAY_CONNECT_TIMEOUT, TcpStream::connect(&addr))
        .await
        .context("timed out connecting to relay")?
        .with_context(|| format!("failed to connect to relay {addr}"))?;

    if !use_tls {
        return Ok(RelayStream::Tcp(stream));
    }

    let config = tls_client_config(allow_bad_certificate);
    let connector = TlsConnector::from(Arc::new(config));
    let server_name = ServerName::try_from(host.to_owned())
        .with_context(|| format!("invalid relay TLS server name {host:?}"))?;
    let stream = timeout(
        RELAY_CONNECT_TIMEOUT,
        connector.connect(server_name, stream),
    )
    .await
    .context("timed out during relay TLS handshake")?
    .with_context(|| format!("failed TLS handshake with relay {addr}"))?;

    Ok(RelayStream::Tls(Box::new(stream)))
}

fn tls_client_config(allow_bad_certificate: bool) -> ClientConfig {
    let mut roots = RootCertStore::empty();
    roots.extend(TLS_SERVER_ROOTS.iter().cloned());
    let builder = ClientConfig::builder();
    if allow_bad_certificate {
        builder
            .dangerous()
            .with_custom_certificate_verifier(Arc::new(NoCertificateVerification))
            .with_no_client_auth()
    } else {
        builder.with_root_certificates(roots).with_no_client_auth()
    }
}

#[derive(Debug)]
struct NoCertificateVerification;

impl ServerCertVerifier for NoCertificateVerification {
    fn verify_server_cert(
        &self,
        _end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> Result<ServerCertVerified, tokio_rustls::rustls::Error> {
        Ok(ServerCertVerified::assertion())
    }

    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, tokio_rustls::rustls::Error> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn verify_tls13_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, tokio_rustls::rustls::Error> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        vec![
            SignatureScheme::RSA_PKCS1_SHA256,
            SignatureScheme::RSA_PKCS1_SHA384,
            SignatureScheme::RSA_PKCS1_SHA512,
            SignatureScheme::ECDSA_NISTP256_SHA256,
            SignatureScheme::ECDSA_NISTP384_SHA384,
            SignatureScheme::RSA_PSS_SHA256,
            SignatureScheme::RSA_PSS_SHA384,
            SignatureScheme::RSA_PSS_SHA512,
            SignatureScheme::ED25519,
        ]
    }
}

async fn read_control_line<S>(stream: &mut S) -> anyhow::Result<Vec<u8>>
where
    S: AsyncRead + Unpin,
{
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

pub async fn read_control_line_blocking<S>(stream: &mut S) -> anyhow::Result<Vec<u8>>
where
    S: AsyncRead + Unpin,
{
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
