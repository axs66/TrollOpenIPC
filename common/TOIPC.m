#import "TOIPC.h"
#import <notify.h>

NSString * const kTOIPCPlistPath = @"/var/mobile/TrollOpen/com.charlieleung.TrollOpen.plist";

NSString * const kTOIPCNotifyRequestInfo        = @"TrollOpenRequestInfo";
NSString * const kTOIPCNotifyRequestSplitLayout = @"TrollOpenRequestSplitLayout";

static NSString * const kTOIPCDirPath = @"/var/mobile/TrollOpen";

void TOIPCEnsureDir(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if ([fm fileExistsAtPath:kTOIPCDirPath isDirectory:&isDir] && isDir) return;

    NSError *err = nil;
    [fm createDirectoryAtPath:kTOIPCDirPath
  withIntermediateDirectories:YES
                   attributes:@{NSFilePosixPermissions: @(0777)}
                        error:&err];
    if (err) {
        NSLog(@"[TOIPC] create dir error: %@", err);
    }
}

BOOL TOIPCWritePlist(NSDictionary *dict) {
    if (![dict isKindOfClass:[NSDictionary class]]) return NO;
    TOIPCEnsureDir();

    // 原子写入，避免接收端读到半截
    BOOL ok = [dict writeToFile:kTOIPCPlistPath atomically:YES];
    if (!ok) NSLog(@"[TOIPC] write plist failed");
    return ok;
}

void TOIPCSendDarwin(NSString *name) {
    if (name.length == 0) return;
    notify_post(name.UTF8String);
}

void TOIPCSendInfo(NSString *info) {
    if (info.length == 0) return;

    NSDictionary *dict = @{
        @"info": info,
        @"ts": @([[NSDate date] timeIntervalSince1970]) // 可选：区分新旧
    };
    if (TOIPCWritePlist(dict)) {
        TOIPCSendDarwin(kTOIPCNotifyRequestInfo);
    }
}

void TOIPCSendSplitId(NSString *bundleIdOrSplitId) {
    if (bundleIdOrSplitId.length == 0) return;

    NSDictionary *dict = @{
        @"splitId": bundleIdOrSplitId,
        @"ts": @([[NSDate date] timeIntervalSince1970])
    };
    if (TOIPCWritePlist(dict)) {
        TOIPCSendDarwin(kTOIPCNotifyRequestSplitLayout);
    }
}
