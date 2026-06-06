# TermBridge

> Remote terminal, no public IP required.  
> 远程终端，无需公网 IP。

[English](#english) | [中文](#中文)

---

## English

### What is TermBridge?

TermBridge lets you control your PC's terminal from your phone (or another PC) — without opening any ports, without a public IP, and without traditional SSH.

Your PC runs a lightweight agent that connects outbound to a relay server. Your phone (Flutter client) connects to the same relay. The relay pairs them and forwards bytes — it never sees your commands or terminal output.

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│  Mobile / Client │────▶│  Relay Server │◀────│    PC Agent      │
│  (Flutter + Rust)│     │    (Go)       │     │   (Rust core)    │
└─────────────────┘     └──────────────┘     └────────┬────────┘
                                                       │
                                              ┌────────▼────────┐
                                              │  Shell / PTY     │
                                              │  PowerShell,Bash │
                                              └─────────────────┘
```

**Key properties:**
- The PC agent connects **outbound** to the relay — no inbound ports, no firewall changes
- The relay **only forwards bytes** — it does not parse terminal content, SSH keys, or commands
- Terminals behave like real terminals: `cd` persists, Ctrl+C works, resize works, interactive programs work
- Mobile-first Flutter client with a Rust core for SSH and PTY

### Project Layout

```
termbridge/
├── client/                  Flutter app (Dart UI + Rust core)
│   ├── lib/                 Flutter UI, state, bridge facade
│   ├── rust/                Rust core: controller/agent, SSH, PTY
│   ├── android/             Android shell
│   ├── windows/             Windows shell
│   ├── linux/               Linux shell
│   ├── macos/               macOS shell
│   ├── ios/                 iOS shell
│   ├── third_party/         Vendored dependencies (patched xterm)
│   └── flutter_rust_bridge.yaml
├── server/                  Relay server (Go)
│   ├── cmd/relay/           Relay entrypoint
│   └── docs/                Architecture & product notes
└── shared/                  Shared protocol types (Go)
    └── protocol/            Relay control messages
```

### Prerequisites

| Component | Requires |
|-----------|----------|
| **Relay server** | Go ≥ 1.25 |
| **Client (Rust core)** | Rust toolchain (stable), `cargo` |
| **Client (Flutter)** | Flutter ≥ 3.24, Android SDK / Visual Studio / Xcode / GTK3 |
| **Android** | `cargo-ndk`, Android NDK |
| **Linux desktop** | `libgtk-3-dev`, `libglib2.0-dev` |

### Quick Start

#### 1. Build & run the relay server

```powershell
# Build
go -C server build -o bin\relay.exe .\cmd\relay

# Run (development mode — use a shared token)
.\server\bin\relay.exe -addr :8080 -token dev-token
```

#### 2. Build the Flutter client

```powershell
cd client

# Install Flutter/Rust bridge codegen (once)
cargo install flutter_rust_bridge_codegen

# Generate Dart↔Rust glue code
flutter_rust_bridge_codegen generate

# Get Flutter dependencies
flutter pub get

# Build for your target platform:

# Windows
flutter build windows

# Android
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
cargo install cargo-ndk
flutter build apk --release

# Linux
flutter build linux

# macOS (on a Mac)
flutter build macos

# iOS (on a Mac)
flutter build ios --no-codesign
```

#### 3. Run the client

```powershell
# Windows desktop — debug mode
cd client
flutter run -d windows

# Or run the release binary directly
.\client\build\windows\x64\runner\Release\mobile_remote_terminal.exe
```

### Configuration

The client connects to a relay server. Configuration is stored locally via `shared_preferences`.

| Setting | Description | Default |
|---------|-------------|---------|
| Relay address | Host:port of the relay server | `localhost:8080` |
| Auth token | Shared secret for relay authentication | (required) |
| Device ID | Identifies the target PC agent | (discovered from relay) |

### Platform Support

| Platform | Client | Agent (Rust core) |
|----------|--------|-------------------|
| Windows x64 | ✅ | ✅ (ConPTY) |
| Android | ✅ | ✅ (PTY via Rust) |
| Linux | ✅ | ✅ (PTY) |
| macOS | ✅ | ✅ (PTY) |
| iOS | ✅ | ✅ (PTY via Rust) |

### Architecture

**Control plane vs. data plane:**

- **Control plane** (JSON): device registration, session open/close, heartbeat, pairing
- **Data plane** (raw bytes): terminal stdin/stdout — forwarded byte-by-byte by the relay

The relay reads only the first JSON control line to pair streams, then switches to transparent byte forwarding. It never parses SSH handshakes, terminal output, ANSI sequences, or user commands.

**Why SSH over a private stream?**

SSH gives us mature session/channel/PTY semantics (resize, signals, exit codes) without reinventing the wheel. We run SSH over a virtual `net.Conn` backed by the relay's byte stream — no real TCP port involved on the agent side.

### Vendored Dependencies

`client/third_party/xterm/` contains a patched copy of `xterm.dart` 4.0.0 that adds `viewId` to `TextInputConfiguration` for Flutter ≥ 3.44 Windows compatibility. See the `dependency_overrides` section in `client/pubspec.yaml`.

### Related Projects

- [Upterm](https://github.com/owenthereal/upterm) — reverse SSH tunnel model
- [ShellHub](https://github.com/shellhub-io/shellhub) — centralized SSH gateway
- [ttyd](https://github.com/tsl0922/ttyd) — terminal over WebSocket

### License

Apache 2.0 — see [LICENSE](LICENSE).

---

## 中文

### TermBridge 是什么？

TermBridge 让你用手机（或另一台电脑）远程控制家用 PC 的终端 — 不需要公网 IP，不需要开放端口，不需要传统 SSH。

PC 上运行一个轻量 Agent，主动向外连接 Relay 服务器。手机（Flutter 客户端）也连接同一个 Relay。Relay 负责配对和转发字节流 — 它永远不会看到你的命令内容或终端输出。

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│  手机 / 客户端    │────▶│  Relay 服务器  │◀────│    PC Agent      │
│  (Flutter + Rust)│     │    (Go)       │     │   (Rust 核心)    │
└─────────────────┘     └──────────────┘     └────────┬────────┘
                                                       │
                                              ┌────────▼────────┐
                                              │  Shell / PTY     │
                                              │  PowerShell,Bash │
                                              └─────────────────┘
```

**核心特性：**

- PC Agent **主动向外**连接 Relay — 不需要公网 IP，不需要改防火墙，不需要开 22 端口
- Relay **只转发字节** — 不解析终端内容、SSH 密钥或命令
- 真终端体验：`cd` 后目录保持、Ctrl+C 生效、支持 resize、支持交互式程序
- 移动优先的 Flutter 客户端 + Rust 核心处理 SSH 和 PTY

### 项目结构

```
termbridge/
├── client/                  Flutter 客户端 (Dart UI + Rust 核心)
│   ├── lib/                 Flutter UI、状态管理、桥接门面
│   ├── rust/                Rust 核心: controller/agent、SSH、PTY
│   ├── android/             Android 平台壳
│   ├── windows/             Windows 平台壳
│   ├── linux/               Linux 平台壳
│   ├── macos/               macOS 平台壳
│   ├── ios/                 iOS 平台壳
│   ├── third_party/         vendored 依赖 (打过补丁的 xterm)
│   └── flutter_rust_bridge.yaml
├── server/                  Relay 服务器 (Go)
│   ├── cmd/relay/           Relay 入口
│   └── docs/                架构与产品文档
└── shared/                  共享协议定义 (Go)
    └── protocol/            Relay 控制消息
```

### 环境要求

| 组件 | 依赖 |
|------|------|
| **Relay 服务器** | Go ≥ 1.25 |
| **客户端 Rust 核心** | Rust 工具链 (stable), `cargo` |
| **客户端 Flutter** | Flutter ≥ 3.24, Android SDK / Visual Studio / Xcode / GTK3 |
| **Android 构建** | `cargo-ndk`, Android NDK |
| **Linux 桌面构建** | `libgtk-3-dev`, `libglib2.0-dev` |

### 快速开始

#### 1. 编译并启动 Relay 服务器

```powershell
# 编译
go -C server build -o bin\relay.exe .\cmd\relay

# 启动（开发模式 — 使用共享 token）
.\server\bin\relay.exe -addr :8080 -token dev-token
```

#### 2. 编译 Flutter 客户端

```powershell
cd client

# 安装 Flutter/Rust 桥接代码生成器（仅需一次）
cargo install flutter_rust_bridge_codegen

# 生成 Dart↔Rust 胶水代码
flutter_rust_bridge_codegen generate

# 获取 Flutter 依赖
flutter pub get

# 各平台构建：

# Windows
flutter build windows

# Android
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
cargo install cargo-ndk
flutter build apk --release

# Linux
flutter build linux

# macOS（需要在 Mac 上）
flutter build macos

# iOS（需要在 Mac 上）
flutter build ios --no-codesign
```

#### 3. 运行客户端

```powershell
# Windows 桌面 — 调试模式
cd client
flutter run -d windows

# 或直接运行 Release 二进制
.\client\build\windows\x64\runner\Release\mobile_remote_terminal.exe
```

### 配置说明

客户端通过 `shared_preferences` 本地存储连接配置。

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| Relay 地址 | Relay 服务器的 Host:Port | `localhost:8080` |
| 认证 Token | 连接 Relay 的共享密钥 | (必填) |
| 设备 ID | 目标 PC Agent 的标识 | (从 Relay 发现) |

### 平台支持

| 平台 | 客户端 | Agent (Rust 核心) |
|------|--------|-------------------|
| Windows x64 | ✅ | ✅ (ConPTY) |
| Android | ✅ | ✅ (PTY via Rust) |
| Linux | ✅ | ✅ (PTY) |
| macOS | ✅ | ✅ (PTY) |
| iOS | ✅ | ✅ (PTY via Rust) |

### 架构说明

**控制面 vs 数据面：**

- **控制面**（JSON）：设备注册、session 打开/关闭、心跳、配对
- **数据面**（原始字节流）：终端 stdin/stdout — Relay 逐字节转发

Relay 只读取第一条 JSON 控制消息来配对数据流，之后切换为透明字节转发。Relay 永远不解析 SSH 握手、终端输出、ANSI 转义序列或用户命令。

**为什么在私有连接上跑 SSH？**

SSH 提供了成熟的 session/channel/PTY 语义（resize、signal、exit code），不需要自己重新发明。我们把 SSH 跑在 Relay 字节流支撑的虚拟 `net.Conn` 上 — Agent 端不涉及真实 TCP 端口。

### Vendored 依赖

`client/third_party/xterm/` 包含打过补丁的 `xterm.dart` 4.0.0，增加了 `viewId` 参数以兼容 Flutter ≥ 3.44 的 Windows 桌面端文本输入。详见 `client/pubspec.yaml` 中的 `dependency_overrides`。

### 参考项目

- [Upterm](https://github.com/owenthereal/upterm) — reverse SSH tunnel 模型
- [ShellHub](https://github.com/shellhub-io/shellhub) — 集中式 SSH 网关
- [ttyd](https://github.com/tsl0922/ttyd) — WebSocket 终端

### 开源协议

Apache 2.0 — 详见 [LICENSE](LICENSE)。
