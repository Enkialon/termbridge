# TH Remote Terminal

TH has two product boundaries, plus a small shared protocol module:

```text
server/  Server side: relay, users/devices/sessions later
client/  User-installed Flutter client with Dart UI and Rust core
shared/  Wire protocol types shared by server and client core code
```

The client is shaped as one app with two roles: it can control remote devices
and, on supported platforms, expose the local device through the Rust core.

## Layout

```text
client/
  lib/                  Flutter UI, configuration, state, and bridge facade
  rust/                 Rust core for controller/agent runtime, SSH, and PTY
  flutter_rust_bridge.yaml
  android/              Android client shell

server/
  cmd/
    relay/              Relay server entrypoint
  docs/                 Product and architecture notes

shared/
  protocol/             Relay control messages and plugin channel constants
```

## Build Server

```powershell
go -C server build -o bin\relay.exe .\cmd\relay
```

Run relay locally:

```powershell
.\server\bin\relay.exe -addr :8080 -token dev-token
```

## Build Client Rust Core

The Rust core is embedded by the Flutter client. It owns the controller/agent
runtime boundary, SSH transport, and PTY/ConPTY integration.

Generate Dart/Rust bridge glue from the Flutter client root:

```powershell
cd client
cargo install flutter_rust_bridge_codegen
flutter_rust_bridge_codegen generate
cd ..
```

Check the Rust core:

```powershell
cargo build --manifest-path client\rust\Cargo.toml
```

## Build Android Client

```powershell
cd client
cargo install cargo-ndk
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
flutter pub get
flutter build apk --release --no-shrink
```

The Android Gradle build runs `cargo ndk` automatically and packages the Rust
core as `libth_client_core.so` for the configured Android ABIs.

## Runtime Shape

```text
Client controller role
  -> server relay
  -> client agent role
  -> local shell / PTY / ConPTY
```

The relay reads only the first JSON control line, pairs controller and agent
streams, then forwards bytes. Terminal data and plugin payloads are not parsed
by the relay.
