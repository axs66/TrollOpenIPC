# TrollOpen IPC Framework

一个基于 **Darwin Notification + Shared Plist** 的  
**iOS 越狱环境跨进程通信（IPC）解决方案**

> 适用于 iOS 15+ / iOS 16+  
> 已在 **Dopamine（rootless）** 环境下验证  
> 典型使用场景：SpringBoard 控制、分屏/布局、插件联动、系统级动作触发

---

## ✨ 项目特性

- ✅ 真·跨进程通信（App ↔ SpringBoard ↔ Daemon）
- ✅ 无需 XPC / mach message，结构简单、稳定
- ✅ Darwin 通知即触发（无 RunLoop 依赖）
- ✅ Plist 传参，灵活扩展
- ✅ 支持多命令、多业务场景
- ✅ 完全适配 rootless 越狱

---

## 🧠 功能层级结构（你现在真正拥有的能力）
## 一、IPC 核心层（common/）

这是你现在最值钱的一层：

✔ Darwin Notification（门铃）

✔ Shared Plist（信箱）

✔ Command Queue（队列）

✔ ACK / 去重 / 防抖

✔ rootless 适配

✔ 可被任意 tweak / daemon / app 复用

这一层已经可以独立抽出来作为“通用 IPC 框架”。

## 二、执行层（ReceiverSB / SpringBoard）

这一层是系统级能力的入口：

✔ 常驻 SpringBoard

✔ 可执行系统动作

✔ 私有 API 拉起 App（多种 fallback）

✔ 解析 splitId（单 App / 双 App）

✔ 真正对接你“自定义分屏引擎”的位置已经固定

换句话说：
只要你补上 split layout 的那一行调用，这个项目就“进化完成”。

## 三、触发层（SenderApp / App 内）

这是“用户交互入口”：

✔ App 内触发（示例：微信）

✔ 悬浮按钮 demo

✔ 一键发送 split 命令

✔ 可换成：手势 / 设置项 / 菜单项

## 📦 项目结构

```text
TrollOpenIPC/
├── README.md
├── LICENSE
├── .gitignore
│
├── common/                          # ⭐ IPC 核心公共模块
│   ├── TOIPC.h                      # IPC 接口定义（通知名 / 队列 / ACK）
│   └── TOIPC.m                      # IPC 实现（plist + notify + queue）
│
├── ReceiverSB/                      # ⭐ 接收端（SpringBoard 执行层）
│   ├── Makefile
│   ├── control
│   └── Tweak.xm
│       ├─ 注册 Darwin 通知监听
│       ├─ 读取 shared plist
│       ├─ 处理 queue[] 中的命令
│       ├─ 防抖 / 去重 / ACK 回写
│       ├─ HandleInfo(info)
│       ├─ HandleSplit(splitId)
│       │   ├─ 支持 "A|B" 解析
│       │   ├─ SBOpenAppWithBundleID()
│       │   ├─ 延迟拉起第二个 App
│       │   └─ 🔌 预留 Custom Split Layout Engine 对接点
│       └─ 日志写入 /var/mobile/Library/Logs/TrollOpenIPC.log
│
├── SenderApp/                       # ⭐ 发送端（App 内触发）
│   ├── Makefile
│   ├── control
│   └── Tweak.xm
│       ├─ App 注入（示例：WeChat）
│       ├─ 悬浮按钮 "Split"
│       ├─ 点击后 Enqueue Split 命令
│       └─ TOIPCEnqueueCommand(type=Split, payload)
│
└── docs/ (可选，未来扩展)
    ├── architecture.md              # 架构说明（可选）
    ├── demo.gif                     # Demo GIF（可选）
    └── release-notes.md             # Release Notes（可选）
