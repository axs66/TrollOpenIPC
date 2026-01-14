#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import "../common/TOIPC.h"

static NSString * const kLogPath = @"/var/mobile/Library/Logs/TrollOpenIPC.log";

static void TOLog(NSString *fmt, ...) {
    va_list args; va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);

    NSLog(@"[TOIPC] %@", msg);
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];

    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:kLogPath];
    if (!fh) {
        [[NSFileManager defaultManager] createFileAtPath:kLogPath contents:nil attributes:nil];
        fh = [NSFileHandle fileHandleForWritingAtPath:kLogPath];
    }
    [fh seekToEndOfFile];
    [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}

static NSDictionary *ReadPlist(void) {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:kTOIPCPlistPath];
    return [d isKindOfClass:[NSDictionary class]] ? d : nil;
}

// 你在这里写“真正执行逻辑”
static void HandleInfo(NSString *info) {
    TOLog(@"HandleInfo info=%@", info);

    // TODO：例如根据 info 做打开 URL / 触发某逻辑
    // 示例（仅演示）：如果是 "ping" 就回个日志
    if ([info isEqualToString:@"ping"]) {
        TOLog(@"pong");
    }
}

static void HandleSplit(NSString *splitId) {
    TOLog(@"HandleSplit splitId=%@", splitId);

    // TODO：这里接你的“分屏/布局/拉起”实现
    // 先给你一个占位：仅打印
    // 如果你要做“拉起 App”，可以在这里进一步对接 SpringBoard 私有 API（你后续告诉我目标我再给对接点）
}

// Darwin 回调（必须是 C 函数指针）
static void TrollOpenDarwinCallback(CFNotificationCenterRef center,
                                   void *observer,
                                   CFStringRef name,
                                   const void *object,
                                   CFDictionaryRef userInfo)
{
    @autoreleasepool {
        NSDictionary *plist = ReadPlist();
        if (!plist) {
            TOLog(@"plist missing or invalid");
            return;
        }

        if (CFStringCompare(name, (CFStringRef)kTOIPCNotifyRequestInfo, 0) == kCFCompareEqualTo) {
            NSString *info = plist[@"info"];
            if ([info isKindOfClass:[NSString class]] && info.length) {
                HandleInfo(info);
            } else {
                TOLog(@"info invalid");
            }
            return;
        }

        if (CFStringCompare(name, (CFStringRef)kTOIPCNotifyRequestSplitLayout, 0) == kCFCompareEqualTo) {
            NSString *sid = plist[@"splitId"];
            if ([sid isKindOfClass:[NSString class]] && sid.length) {
                HandleSplit(sid);
            } else {
                TOLog(@"splitId invalid");
            }
            return;
        }
    }
}

static void RegisterObservers(void) {
    CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();

    CFNotificationCenterAddObserver(darwin,
                                    NULL,
                                    TrollOpenDarwinCallback,
                                    (CFStringRef)kTOIPCNotifyRequestInfo,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);

    CFNotificationCenterAddObserver(darwin,
                                    NULL,
                                    TrollOpenDarwinCallback,
                                    (CFStringRef)kTOIPCNotifyRequestSplitLayout,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);

    TOLog(@"Registered Darwin observers");
}

%ctor {
    @autoreleasepool {
        RegisterObservers();
    }
}
