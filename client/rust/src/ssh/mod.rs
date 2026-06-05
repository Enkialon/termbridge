pub mod client;
#[cfg(not(target_os = "android"))]
pub mod server;

pub use client::{RemoteShell, ShellInput, SshClientConfig, open_remote_shell};
#[cfg(not(target_os = "android"))]
pub use server::{SshServerConfig, run_pty_ssh_server};
