# Mobile Remote Terminal 核心需求与技术方案

> 面向 Codex 执行的产品/技术需求文档  
> 当前版本目标：先实现最核心的“远程终端能力”，不做 AI 插件、不做 Git Diff、不做文件树。  
> 后续插件方向：Git Diff、文件预览、Claude Code/Codex/OpenCode 会话增强。

---

## 1. 一句话定义

这是一个 **手机优先的远程终端工具**。

它的作用类似远程桌面：让用户远程控制自己的家用电脑。  
但它不传输桌面画面，只传输终端输入输出。

更准确地说：

> 连接方式不像 SSH，传输行为接近 SSH。  
> PC 不开放 SSH 端口，而是由 PC Agent 主动连接 Relay；手机也连接 Relay；Relay 负责配对和转发；终端会话走 SSH-like / SSH channel / PTY 字节流。

---

## 2. 核心目标

第一阶段只做一个最小可用核心：

```text
手机 / 客户端
  ↓
Relay Server
  ↓
PC Agent
  ↓
SSH Server / PTY / ConPTY
  ↓
Shell / PowerShell / Bash / Zsh / Git Bash
```

用户能在远端执行：

```bash
pwd
cd /path/to/project
ls
git status
mvn test
npm run build
codex
claude
opencode
```

第一阶段只验证：

1. 家用电脑不用公网 IP；
2. 不开放 22 端口；
3. PC Agent 主动连接 Relay；
4. 手机/客户端通过 Relay 找到 PC；
5. 建立真实终端 session；
6. 能执行交互式命令；
7. 能 `cd` 后保持当前目录；
8. 能运行长时间命令；
9. 能支持 Ctrl+C、Tab、方向键、resize；
10. 能断线后重新连接或重新打开 session。

---

## 3. 非目标

第一阶段明确不做：

```text
不做远程桌面
不传输屏幕视频
不做完整 IDE
不做 AI Agent 任务系统
不实现 Codex/Claude 的上下文记忆
不做 Git Diff 插件
不做文件树
不做多用户协作
不做复杂权限系统
不做 P2P 打洞
```

第一阶段只做：

```text
远程终端核心
```

---

## 4. 为什么不是原生 SSH

传统 SSH：

```text
手机 SSH 客户端 → 家用电脑 22 端口
```

问题：

1. 家用电脑通常没有公网 IP；
2. 路由器端口转发麻烦；
3. 暴露 22 端口有安全风险；
4. 手机端 SSH 体验粗糙；
5. 不方便后续做设备列表、Diff 插件、命令块、移动端 UI。

本项目：

```text
PC Agent → Relay ← 手机/客户端
```

PC Agent 主动向公网 Relay 建立长连接，因此不需要公网 IP，也不需要开放 SSH 端口。

---

## 5. 设计原则

### 5.1 连接方式私有化

连接层使用自己的协议，负责：

```text
设备注册
设备在线状态
手机找电脑
Relay 路由
Session 创建
心跳
断线重连
鉴权
后续打洞协商
```

### 5.2 传输行为接近 SSH

终端层应接近 SSH 的模型：

```text
认证
开 session/channel
分配 PTY
stdin stream
stdout/stderr stream
resize
signal
exit status
```

不要做成简单的：

```http
POST /exec
{
  "command": "ls"
}
```

那只是远程命令执行器，不是真终端，无法良好支持 `cd` 状态、交互式 CLI、vim/top/codex/claude 等程序。

### 5.3 数据面走字节流

终端输入输出不应该用 JSON 包每条消息。

推荐：

```text
Control Plane：JSON / Protobuf
Data Plane：Raw byte stream
```

低频控制消息可以用 JSON：

```json
{
  "type": "session.open",
  "sessionId": "s1",
  "cols": 90,
  "rows": 28
}
```

终端数据直接走二进制流：

```text
stdin bytes →
← stdout bytes
```

### 5.4 Relay 不理解终端内容

Relay 只做：

```text
deviceId -> sessionId -> stream 转发
```

Relay 不解析：

```text
SSH 内容
终端输出
命令内容
用户输入
ANSI 控制序列
```

这样有利于安全和后续端到端加密。

---

## 6. 推荐架构

### 6.1 MVP 架构

```text
┌──────────────────────┐
│ Mobile / CLI Client  │
│ - 输入命令             │
│ - 展示终端输出          │
└──────────┬───────────┘
           │
           │ Private Stream / SSH over virtual conn
           ▼
┌──────────────────────┐
│ Relay Server         │
│ - 设备注册             │
│ - 连接配对             │
│ - 流转发               │
│ - 鉴权                 │
└──────────┬───────────┘
           │
           │ Private Stream
           ▼
┌──────────────────────┐
│ PC Agent             │
│ - 主动连接 Relay       │
│ - 内嵌 SSH Server      │
│ - 管理 PTY/ConPTY      │
│ - 启动 Shell           │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Shell                │
│ PowerShell/Bash/etc. │
└──────────────────────┘
```

### 6.2 SSH over 私有连接

Go 的 `golang.org/x/crypto/ssh` 可以实现 SSH client/server。  
关键思路：

> SSH 不一定非要跑在真实 TCP 上。只要能提供一个双向字节流，就可以包装成 `net.Conn`，让 SSH 跑在这条虚拟连接上。

也就是说：

```text
Mobile Client SSH Client
  ⇅
Virtual net.Conn
  ⇅
Relay byte stream
  ⇅
Virtual net.Conn
  ⇅
PC Agent SSH Server
  ⇅
PTY / ConPTY
```

### 6.3 为什么这样做

优点：

1. 不需要自己完整设计 SSH-like channel 协议；
2. 复用成熟 SSH 的 session/channel/PTY 语义；
3. 更接近用户熟悉的终端行为；
4. 后续可以扩展文件传输、端口转发等能力；
5. Relay 只转发字节，不需要理解业务；
6. 连接方式仍然可以是产品化的：设备列表、扫码绑定、Relay、中继、打洞。

---

## 7. 技术选型建议

### 7.1 推荐 MVP 技术栈

```text
语言：Go
Relay：Go
PC Agent：Go
CLI Client：Go
手机端：第二阶段再做
终端传输：golang.org/x/crypto/ssh
PTY：
  Linux/macOS：creack/pty 或类似库
  Windows：ConPTY / go-pty
前端终端：xterm.js（如果做 Web/PWA）
```

### 7.2 为什么先用 Go

Go 适合：

```text
网络连接
长连接
并发流转发
CLI 工具
单文件发布
跨平台 Agent
Relay Server
SSH client/server
```

第一阶段建议先用 Go 写：

```text
relay
agent
cli-client
```

先不要急着写手机 App。

### 7.3 手机端能不能用 Go

可以，但不建议整个 App 都用 Go 写。

更合理：

```text
移动端 UI：Flutter / Kotlin / Swift / React Native
连接核心：可选用 Go，通过 gomobile bind 生成库
```

但第一阶段先不要做手机端。  
先用 Go CLI 模拟手机端，把核心连接和 SSH 传输跑通。

---

## 8. 第一阶段实现路线

### Phase 0：本地 SSH + PTY 验证

目标：

```text
Go SSH Server → PTY → Shell
Go SSH Client → SSH Server
```

验收：

```text
能登录
能打开 shell
能执行 cd / ls / pwd
能 Ctrl+C
能 resize
```

暂时不接 Relay。

### Phase 1：Relay 字节流转发

目标：

```text
CLI Client → Relay → PC Agent → SSH Server → PTY
```

Relay 只做流转发。

验收：

```text
PC Agent 主动连接 Relay
CLI Client 连接 Relay
Relay 根据 deviceId/sessionId 配对
SSH 能通过 Relay 跑起来
能执行 cd / ls / pwd
```

### Phase 2：设备绑定

目标：

```text
PC Agent 启动后生成 deviceId + pairingCode
Client 输入 pairingCode 连接设备
```

验收：

```text
未绑定设备不能连接
绑定后可连接
Relay 能看到设备在线/离线
```

### Phase 3：Session 管理

目标：

```text
创建 session
关闭 session
断线后重新连接
```

验收：

```text
能打开多个 session
能关闭 session
客户端断开后 PC Agent 不崩
重新连接能新建或恢复 session
```

### Phase 4：基础移动端 Web/PWA

目标：

```text
浏览器 + xterm.js 访问 Relay
展示远程终端
```

注意：

如果是纯浏览器，浏览器端不方便直接跑 Go SSH client。  
可以先用两种方案之一：

方案 A：浏览器只做终端 UI，SSH 在后端或 Agent 侧终止。  
方案 B：移动端先做原生 App，再把 Go core 绑定进去。

MVP 可以先不做 PWA，先做 CLI Client。

---

## 9. 消息与流协议草案

### 9.1 控制消息

控制消息可用 JSON 或 Protobuf。

```json
{
  "type": "device.register",
  "deviceId": "home-pc-001",
  "agentVersion": "0.1.0"
}
```

```json
{
  "type": "client.connect",
  "deviceId": "home-pc-001",
  "sessionId": "s1"
}
```

```json
{
  "type": "session.open",
  "sessionId": "s1"
}
```

```json
{
  "type": "session.close",
  "sessionId": "s1"
}
```

```json
{
  "type": "heartbeat"
}
```

### 9.2 数据帧

终端数据用二进制 frame。

最简单帧格式：

```text
1 byte  frameType
16 byte sessionId / streamId
N byte  payload
```

frameType：

```text
0x01 control
0x02 stream_data
0x03 stream_close
0x04 ping
0x05 pong
```

也可以第一版简化为：

```text
一个 session 一个 WebSocket/TCP stream
Relay 直接双向 copy
```

第一版越简单越好。

---

## 10. 开源项目参考

### 10.1 Upterm

用途：重点参考。

Upterm 的模型非常接近本项目底层：

```text
本机启动 SSH server
本机主动建立 reverse SSH tunnel 到 uptermd
客户端通过 uptermd 连接 terminal session
```

适合参考：

```text
reverse SSH tunnel
terminal sharing
host/client/server 分层
SSH over relay 的整体思路
```

不适合直接照搬的地方：

```text
它偏临时 terminal sharing
不是常驻设备远控
不是手机优先产品
没有 Git Diff 插件
```

参考地址：

```text
https://github.com/owenthereal/upterm
https://upterm.dev/
```

### 10.2 ShellHub

用途：参考设备网关。

ShellHub 是 centralized SSH gateway，允许用户通过浏览器或 mobile app 远程访问设备。

适合参考：

```text
设备 Agent
中心网关
Web terminal
设备在线状态
远程 SSH gateway
```

不适合直接照搬的地方：

```text
偏 Linux 设备管理
产品较重
不是移动端 Warp-like 终端
```

参考地址：

```text
https://github.com/shellhub-io/shellhub
https://www.shellhub.io/
```

### 10.3 Teleport

用途：参考企业级 reverse tunnel / SSH access / audit。

适合参考：

```text
reverse tunnel
proxy
auth
RBAC
session recording
```

不建议直接二开，太重。

参考地址：

```text
https://github.com/gravitational/teleport
https://goteleport.com/
```

### 10.4 VibeTunnel

用途：参考浏览器终端和移动端体验。

适合参考：

```text
浏览器访问 terminal
session UI
xterm.js 使用方式
在路上控制 terminal/agent 的产品形态
```

参考地址：

```text
https://github.com/amantus-ai/vibetunnel
```

### 10.5 ttyd / WeTTY

用途：参考最小 Web Terminal。

适合参考：

```text
PTY <-> WebSocket <-> xterm.js
Web 终端渲染
ANSI / 输入处理
```

参考地址：

```text
https://github.com/tsl0922/ttyd
https://github.com/butlerx/wetty
```

### 10.6 RustDesk

用途：只参考连接模型，不建议直接 fork。

RustDesk 的远程桌面服务端分为：

```text
ID / Rendezvous server
Relay server
```

适合参考：

```text
设备发现
Rendezvous
Relay
P2P 失败后走中继
自托管服务端
```

不建议直接二开，因为它是远程桌面，代码包含视频、图形、输入、权限等大量本项目不需要的复杂逻辑。

参考地址：

```text
https://github.com/rustdesk/rustdesk
https://github.com/rustdesk/rustdesk-server
```

### 10.7 Go SSH

用途：实现 SSH client/server。

参考地址：

```text
https://pkg.go.dev/golang.org/x/crypto/ssh
https://github.com/gliderlabs/ssh
```

---

## 11. MVP 验收标准

### 11.1 必须通过

```text
1. PC Agent 不监听公网端口
2. PC Agent 主动连接 Relay
3. Client 通过 Relay 连接 PC Agent
4. 能打开远程 shell
5. 能执行 pwd / cd / ls / dir
6. cd 后目录状态保持
7. 能执行 git status
8. 能运行交互式程序
9. Ctrl+C 生效
10. Tab 生效
11. resize 生效
12. 断开连接后服务不崩
```

### 11.2 可选通过

```text
1. 多 session
2. session 恢复
3. 本地配置文件
4. 设备绑定
5. 简单 Token 鉴权
6. 日志输出
```

### 11.3 暂不验收

```text
1. Git Diff 插件
2. 手机 App
3. PWA
4. 文件树
5. AI 插件
6. P2P 打洞
7. 端到端加密
```

---

## 12. 后续插件规划

核心终端稳定后再做插件。

### 12.1 Git Diff 插件

作用：

```text
终端负责执行
Diff 插件负责展示执行后代码改了什么
```

能力：

```text
git status
git diff --numstat
git diff -- file
文件级 diff view
回滚文件
生成 commit message
```

### 12.2 文件插件

能力：

```text
最近文件
Git changed files
单文件预览
复制路径
下载文件
```

### 12.3 Claude Code / Codex 插件

注意：

不要把 Claude/Codex 写进核心。

它们应该是插件：

```text
识别当前 session 是否运行 claude/codex
提供快捷按钮
辅助查看输出
调用 Git Diff 插件看结果
```

即使插件失效，普通终端仍然可用。

---

## 13. 代码量预估

### 13.1 技术 Demo

范围：

```text
Go CLI Client
Go Relay
Go PC Agent
SSH over Relay
PTY shell
```

预计：

```text
7000 - 14000 行
```

### 13.2 可用 MVP

范围：

```text
设备绑定
多 session
断线处理
基础鉴权
Windows/macOS/Linux 初步支持
日志
配置
```

预计：

```text
28000 - 56000 行
```

### 13.3 成熟开源版

范围：

```text
手机 App/PWA
自托管 Relay
自动更新
多设备
安全策略
Git Diff 插件
文件插件
AI CLI 插件
```

预计：

```text
70000 - 120000 行
```

---

## 14. 给 Codex 的实现任务拆分

### Task 1：创建仓库结构

```text
remote-terminal/
  client/
    native/
      host/
  server/
    cmd/
      relay/
    docs/
  shared/
    protocol/
```

### Task 2：实现本地 SSH server + PTY

要求：

```text
Go
golang.org/x/crypto/ssh
Linux/macOS 先用 PTY
Windows 后续补 ConPTY
```

先跑通：

```bash
ssh localhost -p <port>
```

能进入 shell。

### Task 3：实现 Relay

要求：

```text
Relay 接收 Agent 连接
Relay 接收 Client 连接
根据 deviceId/sessionId 配对
双向复制字节流
```

### Task 4：实现 Agent 反向连接

要求：

```text
Agent 启动后主动连 Relay
注册 deviceId
等待 Relay 下发 stream
把 stream 接给内嵌 SSH server
```

### Task 5：实现 CLI Client

要求：

```text
Client 连接 Relay
选择 deviceId
建立 stream
SSH client 跑在该 stream 上
打开 terminal session
```

### Task 6：实现基础控制协议

要求：

```text
device.register
client.connect
session.open
session.close
heartbeat
```

### Task 7：实现基础鉴权

要求：

```text
开发阶段先用 shared token
后续改为设备绑定和密钥
```

### Task 8：补充文档和启动脚本

要求：

```text
README
本地启动 relay
启动 agent
启动 client
示例命令
```

---

## 15. 最终建议

第一阶段不要做大而全。

最小目标：

```text
不用开 SSH 端口，
通过 Relay 连接 PC Agent，
建立 SSH-like 终端 session，
能 cd / ls / git status。
```

只有这个核心跑通，后续 Git Diff、手机 App、AI 插件才有意义。

推荐优先级：

```text
1. 跑通 SSH over private stream
2. 跑通 Relay
3. 跑通 PTY shell
4. 跑通设备绑定
5. 再考虑手机端
6. 最后做 Diff 插件
```
