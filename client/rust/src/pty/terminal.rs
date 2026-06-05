use std::io::{Read, Write};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::time::Duration;

use portable_pty::{CommandBuilder, PtySize, native_pty_system};

#[derive(Debug, Clone)]
pub struct PtyCommandResult {
    pub success: bool,
    pub output: Vec<u8>,
}

pub struct InteractivePty {
    input: Sender<PtyInput>,
}

enum PtyInput {
    Data(Vec<u8>),
    Resize(PtySize),
    Close,
}

pub fn spawn_interactive_pty(
    shell: &str,
    size: PtySize,
) -> anyhow::Result<(InteractivePty, Receiver<Vec<u8>>)> {
    let pty_system = native_pty_system();
    let pair = pty_system.openpty(size)?;

    let mut cmd = CommandBuilder::new(shell);
    cmd.env("TERM", "xterm-256color");

    let child = pair.slave.spawn_command(cmd)?;
    drop(pair.slave);

    let mut reader = pair.master.try_clone_reader()?;
    let mut writer = pair.master.take_writer()?;
    let master = pair.master;
    let mut killer = child.clone_killer();

    let (input_tx, input_rx) = mpsc::channel::<PtyInput>();
    let (output_tx, output_rx) = mpsc::channel::<Vec<u8>>();

    thread::spawn(move || {
        let mut child = child;
        let _ = child.wait();
    });

    thread::spawn(move || {
        let mut buf = [0_u8; 4096];
        loop {
            match reader.read(&mut buf) {
                Ok(0) => break,
                Ok(n) => {
                    if output_tx.send(buf[..n].to_vec()).is_err() {
                        break;
                    }
                }
                Err(_) => break,
            }
        }
    });

    thread::spawn(move || {
        while let Ok(input) = input_rx.recv() {
            match input {
                PtyInput::Data(data) => {
                    if writer.write_all(&data).is_err() {
                        break;
                    }
                    let _ = writer.flush();
                }
                PtyInput::Resize(size) => {
                    let _ = master.resize(size);
                }
                PtyInput::Close => {
                    let _ = killer.kill();
                    break;
                }
            }
        }
    });

    Ok((InteractivePty { input: input_tx }, output_rx))
}

impl InteractivePty {
    pub fn write(&self, data: &[u8]) -> anyhow::Result<()> {
        self.input.send(PtyInput::Data(data.to_vec()))?;
        Ok(())
    }

    pub fn resize(&self, size: PtySize) -> anyhow::Result<()> {
        self.input.send(PtyInput::Resize(size))?;
        Ok(())
    }

    pub fn close(&self) -> anyhow::Result<()> {
        self.input.send(PtyInput::Close)?;
        Ok(())
    }
}

pub fn run_command(command: &str) -> anyhow::Result<PtyCommandResult> {
    let pty_system = native_pty_system();
    let pair = pty_system.openpty(PtySize {
        rows: 24,
        cols: 80,
        pixel_width: 0,
        pixel_height: 0,
    })?;

    let mut cmd = CommandBuilder::new(default_shell());
    cmd.env("TERM", "xterm-256color");
    add_shell_command_args(&mut cmd, command);

    let mut child = pair.slave.spawn_command(cmd)?;
    drop(pair.slave);

    let mut reader = pair.master.try_clone_reader()?;
    let mut output = Vec::new();
    let mut writer = pair.master.take_writer()?;
    writer.flush()?;
    drop(writer);

    let reader_thread = thread::spawn(move || {
        let mut buf = [0_u8; 4096];
        loop {
            match reader.read(&mut buf) {
                Ok(0) => break,
                Ok(n) => output.extend_from_slice(&buf[..n]),
                Err(_) => break,
            }
        }
        output
    });

    let status = child.wait()?;
    thread::sleep(Duration::from_millis(100));
    drop(pair.master);

    let output = reader_thread.join().unwrap_or_default();
    Ok(PtyCommandResult {
        success: status.success(),
        output,
    })
}

pub fn default_shell() -> String {
    if cfg!(windows) {
        std::env::var("COMSPEC").unwrap_or_else(|_| "cmd.exe".to_string())
    } else {
        std::env::var("SHELL").unwrap_or_else(|_| "/bin/sh".to_string())
    }
}

fn add_shell_command_args(cmd: &mut CommandBuilder, command: &str) {
    if cfg!(windows) {
        cmd.arg("/C");
        cmd.arg(command);
    } else {
        cmd.arg("-lc");
        cmd.arg(command);
    }
}
