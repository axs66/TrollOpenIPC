#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const kTOIPCPlistPath;

// Darwin 通知名
FOUNDATION_EXPORT NSString * const kTOIPCNotifyRequestInfo;
FOUNDATION_EXPORT NSString * const kTOIPCNotifyRequestSplitLayout;

// 确保目录存在
void TOIPCEnsureDir(void);

// 原子写 plist
BOOL TOIPCWritePlist(NSDictionary *dict);

// 发送通知（敲门）
void TOIPCSendDarwin(NSString *name);

// 快捷：发 info / splitId
void TOIPCSendInfo(NSString *info);
void TOIPCSendSplitId(NSString *bundleIdOrSplitId);

NS_ASSUME_NONNULL_END
