# TH Client

This directory is the Flutter client app root.

The client is one app with two roles: controller UI in Flutter/Dart and local
agent/runtime capabilities in the embedded Rust core.

## Stack

```text
UI: Flutter
Terminal UI: xterm.dart
Dart core facade: CoreBridge
Local config: shared_preferences
Client core: Rust + russh + portable-pty
Transport: TCP socket to Relay, then SSH over the paired stream
```

TLS is modeled in the config and returns a clear Rust error until the rustls
transport is added.

## Android

Default relay host for the Android emulator:

```text
10.0.2.2:8080
```

Build:

```powershell
cargo install flutter_rust_bridge_codegen
cargo install cargo-ndk
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
flutter_rust_bridge_codegen generate
flutter pub get
flutter build apk --release --no-shrink
```

The Android Gradle build invokes `cargo ndk` before Java precompile and writes
Rust dynamic libraries to `android/app/src/main/jniLibs`.

## Rust Core

Build the embedded core:

```powershell
cargo build --manifest-path rust\Cargo.toml
```
