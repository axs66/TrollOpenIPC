#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import "../common/TOIPC.h"

// ==================== 日志系统 ====================
static NSString * const kLogPath = @"/var/mobile/Library/Logs/TrollOpenIPC.log";

static void TOLog(NSString *fmt, ...) {
    va_list args; va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);

    NSLog(@"[TOIPC] %@", msg);
    
    @autoreleasepool {
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [df stringFromDate:[NSDate date]], msg];

        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:kLogPath];
        if (!fh) {
            [[NSFileManager defaultManager] createFileAtPath:kLogPath contents:nil attributes:nil];
            fh = [NSFileHandle fileHandleForWritingAtPath:kLogPath];
        }
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
}

// ==================== SpringBoard 私有 API 声明 ====================

@interface SBApplication : NSObject
@property (nonatomic, readonly) NSString *bundleIdentifier;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)bundleId;
@end

@interface FBSSystemService : NSObject
+ (instancetype)sharedService;
- (void)openApplication:(NSString *)bundleId options:(NSDictionary *)options clientPort:(unsigned int)port withResult:(void (^)(NSError *))handler;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleId;
@end

@interface SBMainWorkspace : NSObject
+ (instancetype)sharedInstance;
- (void)applicationOpenToSide:(SBApplication *)app;
@end

// ==================== App 拉起实现 ====================

static BOOL SBOpenAppWithBundleID(NSString *bundleId) {
    if (bundleId.length == 0) return NO;
    
    TOLog(@"Attempting to open app: %@", bundleId);
    
    // 方法 1: FBSSystemService (iOS 11+)
    Class FBSClass = objc_getClass("FBSSystemService");
    if (FBSClass) {
        FBSSystemService *service = [FBSClass sharedService];
        if (service) {
            [service openApplication:bundleId options:@{} clientPort:0 withResult:^(NSError *error) {
                if (error) {
                    TOLog(@"FBSSystemService failed: %@", error);
                } else {
                    TOLog(@"FBSSystemService opened: %@", bundleId);
                }
            }];
            return YES;
        }
    }
    
    // 方法 2: LSApplicationWorkspace
    Class LSClass = objc_getClass("LSApplicationWorkspace");
    if (LSClass) {
        LSApplicationWorkspace *workspace = [LSClass defaultWorkspace];
        if ([workspace respondsToSelector:@selector(openApplicationWithBundleID:)]) {
            BOOL success = [workspace openApplicationWithBundleID:bundleId];
            TOLog(@"LSApplicationWorkspace result: %@", success ? @"success" : @"failed");
            return success;
        }
    }
    
    // 方法 3: URL Scheme fallback
    NSString *urlString = [NSString stringWithFormat:@"app-prefs:root=%@", bundleId];
    NSURL *url = [NSURL URLWithString:urlString];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        TOLog(@"Opened via URL scheme: %@", bundleId);
        return YES;
    }
    
    TOLog(@"All methods failed for: %@", bundleId);
    return NO;
}

// ==================== 分屏处理 ====================

static void HandleSplit(NSString *splitId) {
    if (splitId.length == 0) {
        TOLog(@"HandleSplit: empty splitId");
        return;
    }
    
    TOLog(@"HandleSplit: %@", splitId);
    
    // 解析 A|B 格式
    NSArray<NSString *> *components = [splitId componentsSeparatedByString:@"|"];
    
    NSString *bundleA = [components.firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *bundleB = components.count > 1 ? [components[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] : nil;
    
    if (bundleA.length == 0) {
        TOLog(@"HandleSplit: invalid bundleA");
        return;
    }
    
    // 拉起第一个 App
    BOOL openedA = SBOpenAppWithBundleID(bundleA);
    TOLog(@"Opened first app %@: %@", bundleA, openedA ? @"YES" : @"NO");
    
    // 如果有第二个 App，延迟拉起
    if (bundleB.length > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            BOOL openedB = SBOpenAppWithBundleID(bundleB);
            TOLog(@"Opened second app %@: %@", bundleB, openedB ? @"YES" : @"NO");
            
            // TODO: 这里预留自定义分屏引擎对接点
            // 例如: [SplitLayoutEngine activateSplitWithAppA:bundleA appB:bundleB];
            TOLog(@"🔌 Split layout engine hook point: A=%@ B=%@", bundleA, bundleB);
        });
    }
}

// ==================== Info 处理 ====================

static void HandleInfo(NSString *info) {
    TOLog(@"HandleInfo: %@", info);

    if ([info isEqualToString:@"ping"]) {
        TOLog(@"pong");
    }
    
    // 可扩展更多 info 命令处理
}

// ==================== 命令队列处理 ====================

static void ProcessCommandQueue(void) {
    NSArray<NSDictionary *> *commands = TOIPCDequeueCommands();
    if (!commands || commands.count == 0) {
        return;
    }
    
    TOLog(@"Processing %lu commands", (unsigned long)commands.count);
    
    for (NSDictionary *cmd in commands) {
        NSString *uuid = cmd[@"uuid"];
        NSNumber *typeNum = cmd[@"type"];
        NSDictionary *payload = cmd[@"payload"];
        
        if (!uuid || !typeNum || TOIPCIsProcessed(uuid)) {
            continue;
        }
        
        TOIPCCommandType type = (TOIPCCommandType)[typeNum integerValue];
        
        switch (type) {
            case TOIPCCommandTypeInfo: {
                NSString *info = payload[@"info"];
                if ([info isKindOfClass:[NSString class]] && info.length > 0) {
                    HandleInfo(info);
                }
                break;
            }
            case TOIPCCommandTypeSplit: {
                NSString *splitId = payload[@"splitId"];
                if ([splitId isKindOfClass:[NSString class]] && splitId.length > 0) {
                    HandleSplit(splitId);
                }
                break;
            }
            case TOIPCCommandTypeCustom:
            default:
                TOLog(@"Unhandled command type: %ld", (long)type);
                break;
        }
        
        // 标记已处理
        TOIPCMarkProcessed(uuid);
    }
    
    // 定期清理旧记录（保留 1 小时内的）
    TOIPCCleanupProcessed(3600);
}

// ==================== Darwin 回调 ====================

static void TrollOpenDarwinCallback(CFNotificationCenterRef center,
                                   void *observer,
                                   CFStringRef name,
                                   const void *object,
                                   CFDictionaryRef userInfo)
{
    @autoreleasepool {
        NSString *notifyName = (__bridge NSString *)name;
        TOLog(@"Received notification: %@", notifyName);
        
        // 统一处理命令队列
        ProcessCommandQueue();
    }
}

// ==================== 注册观察者 ====================

static void RegisterObservers(void) {
    CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();

    // 监听命令入队通知
    CFNotificationCenterAddObserver(darwin,
                                    NULL,
                                    TrollOpenDarwinCallback,
                                    (CFStringRef)kTOIPCNotifyCommandQueued,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);

    // 向后兼容：监听旧通知名
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

    TOLog(@"✅ Registered Darwin observers for IPC");
}

// ==================== 构造器 ====================

%ctor {
    @autoreleasepool {
        TOLog(@"TrollOpenIPC ReceiverSB loaded");
        RegisterObservers();
    }
}
