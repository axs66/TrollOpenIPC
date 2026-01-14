# TrollOpenIPC 操作指南

## 📦 安装

### 构建产物
构建成功后会生成两个 deb 包：
- **TrollOpenIPCReceiverSB** - 安装到 SpringBoard，负责接收和执行命令
- **TrollOpenIPCSenderApp** - 安装到应用内，负责发送命令

### 安装步骤
1. 将两个 `.deb` 文件传输到设备
2. 使用 Filza 或命令行安装：
   ```bash
   dpkg -i com.axs.trollopenipc.receiver_*.deb
   dpkg -i com.axs.trollopenipc.sender_*.deb
   ```
3. 注销或重启 SpringBoard

---

## 🎯 使用方式

### 方式一：使用内置悬浮按钮（开箱即用）

安装 SenderApp 后，打开任意应用会出现蓝色悬浮按钮 "Split"：
- **拖动**：可自由移动位置，松手自动吸附边缘
- **点击**：发送分屏命令（当前应用 + 微信）

### 方式二：在自己的 Tweak 中调用

#### 1. 引入头文件
```objc
#import "TOIPC.h"
```

#### 2. 发送命令

**发送信息命令：**
```objc
TOIPCSendInfo(@"ping");
```

**发送分屏命令（单个应用）：**
```objc
TOIPCSendSplitId(@"com.tencent.xin");
```

**发送分屏命令（两个应用，格式：A|B）：**
```objc
TOIPCSendSplitId(@"com.tencent.xin|com.apple.mobilesafari");
```

#### 3. 底层 API（高级用法）
```objc
// 入队自定义命令
NSString *uuid = TOIPCEnqueueCommand(TOIPCCommandTypeCustom, @{
    @"action": @"myAction",
    @"data": @"value"
});

// 发送 Darwin 通知
TOIPCSendDarwin(@"TrollOpenCommandQueued");
```

---

## 🔧 与作者原版接口的兼容性

本项目完全兼容作者公开的跨进程通信接口：

| 接口 | 值 |
|-----|-----|
| 通知名（Info） | `TrollOpenRequestInfo` |
| 通知名（Split） | `TrollOpenRequestSplitLayout` |
| Plist 路径 | `/var/mobile/TrollOpen/com.charlieleung.TrollOpen.plist` |
| Info 键名 | `info` |
| Split 键名 | `splitId` |

### 直接使用原始接口（不依赖本框架）

**注册监听：**
```objc
CFNotificationCenterAddObserver(
    CFNotificationCenterGetDarwinNotifyCenter(),
    NULL,
    YourCallbackFunction,
    CFSTR("TrollOpenRequestInfo"),  // 或 "TrollOpenRequestSplitLayout"
    NULL,
    CFNotificationSuspensionBehaviorDeliverImmediately
);
```

**读取数据：**
```objc
NSString *plistPath = @"/var/mobile/TrollOpen/com.charlieleung.TrollOpen.plist";
NSDictionary *plistDict = [NSDictionary dictionaryWithContentsOfFile:plistPath];
NSString *info = plistDict[@"info"];
NSString *splitId = plistDict[@"splitId"];
```

---

## 📂 文件路径

| 路径 | 用途 |
|-----|-----|
| `/var/mobile/TrollOpen/` | IPC 数据目录 |
| `/var/mobile/TrollOpen/com.charlieleung.TrollOpen.plist` | 命令队列 Plist |
| `/var/mobile/TrollOpen/processed.plist` | 已处理命令记录（去重用） |
| `/var/mobile/Library/Logs/TrollOpenIPC.log` | 调试日志 |

---

## 🛠 扩展开发

### 自定义命令处理（ReceiverSB）

编辑 `ReceiverSB/Tweak.xm`，在 `ProcessCommandQueue()` 函数中添加自定义命令处理：

```objc
case TOIPCCommandTypeCustom: {
    NSString *action = payload[@"action"];
    if ([action isEqualToString:@"myAction"]) {
        // 你的自定义逻辑
    }
    break;
}
```

### 对接分屏引擎

在 `HandleSplit()` 函数中已预留对接点：
```objc
// TODO: 这里预留自定义分屏引擎对接点
// 例如: [SplitLayoutEngine activateSplitWithAppA:bundleA appB:bundleB];
TOLog(@"🔌 Split layout engine hook point: A=%@ B=%@", bundleA, bundleB);
```

---

## ⚠️ 注意事项

1. **权限要求**：需要越狱环境，推荐 Dopamine (rootless)
2. **iOS 版本**：iOS 15+ / iOS 16+
3. **防抖机制**：连续发送命令间隔需 > 0.3 秒
4. **日志查看**：`cat /var/mobile/Library/Logs/TrollOpenIPC.log`
