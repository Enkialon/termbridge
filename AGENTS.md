# AGENTS.md — TermBridge

Instructions for AI coding agents working on this repository.

## Build Commands

All build commands must be output for the user to run manually. Do not execute them directly.

### Relay Server
```powershell
go -C server build -o bin\relay.exe .\cmd\relay
```
Run: `.\server\bin\relay.exe -addr :8080 -token dev-token`

### Client — Code Generation (run after any Rust API change)
```powershell
cd client
flutter_rust_bridge_codegen generate
cd ..
```

### Client — Flutter
```powershell
cd client
flutter pub get
flutter build windows          # Windows
flutter build apk --release    # Android
flutter build linux            # Linux
flutter build macos            # macOS
flutter build ios --no-codesign # iOS
```

### Rust Core (check only)
```powershell
cargo build --manifest-path client\rust\Cargo.toml
```

## Rules

1. **No build/run commands** — output the command, let the user execute it
2. **No Rust edits without approval** — Rust changes affect generated glue code and multiple platforms; explain the impact before touching any `.rs` file
3. **Dart/Flutter edits** — must request user confirmation before modifying, creating, or reverting files
4. **Generated files** — `client/rust/src/frb_generated.rs` and `client/lib/src/rust/frb_generated*.dart` are auto-generated; do not edit them
5. **Vendored xterm** — `client/third_party/xterm/` is a patched copy with `viewId` fix for Flutter 3.44+; do not upgrade it from pub without re-applying the patch

## Architecture

```
Client (Flutter + Rust)
  └─ Rust core (client/rust/)
       ├─ controller/   Client-side controller logic
       ├─ agent/        Agent runtime (spawns shells on local device)
       ├─ ssh/          SSH client/server over virtual net.Conn
       ├─ pty/          PTY/ConPTY integration
       ├─ relay/        Relay client connection
       └─ tunnel/       Stream multiplexing

Relay Server (server/cmd/relay/)
  └─ Pairs device IDs → session IDs → byte stream forwarding

Shared Protocol (shared/protocol/)
  └─ Go types for relay control messages
```

## Key Files

| File | Purpose |
|------|---------|
| `client/lib/main.dart` | App entry point, creates Rust bridge |
| `client/lib/src/ui/shared/pages/terminal_page.dart` | Terminal UI page |
| `client/rust/src/frb_api.rs` | Public Rust API surface (generates Dart bridge) |
| `client/rust/src/lib.rs` | Rust crate root |
| `client/flutter_rust_bridge.yaml` | FRB codegen config |
| `server/cmd/relay/main.go` | Relay server entrypoint |
| `shared/protocol/` | Relay wire protocol types |

## Platform-specific Notes

- **Windows**: ConPTY via `portable-pty` crate
- **Linux**: Needs `libgtk-3-dev`, PTY via `portable-pty`
- **macOS**: PTY via `portable-pty`
- **Android**: Rust compiles via `cargo-ndk`, PTY support included
- **iOS**: PTY support included, builds require macOS + Xcode
