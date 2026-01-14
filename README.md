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

## 📦 项目结构

```text
TrollOpenIPC/
├── common/                 # 公共 IPC 模块（发送/接收共用）
│   ├── TOIPC.h
│   └── TOIPC.m
│
├── ReceiverSB/             # 接收端（SpringBoard）
│   ├── Tweak.xm
│   ├── Makefile
│   └── control
│
├── SenderApp/              # 发送端（App 内 / 任意进程）
│   ├── Tweak.xm
│   ├── Makefile
│   └── control
│
├── README.md
├── LICENSE
└── .gitignore
