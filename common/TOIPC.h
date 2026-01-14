#import <Foundation/Foundation.h>
#include <sys/cdefs.h>

NS_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

// ==================== 路径定义 ====================
FOUNDATION_EXPORT NSString *const kTOIPCPlistPath;
FOUNDATION_EXPORT NSString *const kTOIPCDirPath;

// ==================== Darwin 通知名 ====================
FOUNDATION_EXPORT NSString *const kTOIPCNotifyRequestInfo;
FOUNDATION_EXPORT NSString *const kTOIPCNotifyRequestSplitLayout;
FOUNDATION_EXPORT NSString *const kTOIPCNotifyCommandQueued;

// ==================== 命令类型 ====================
typedef NS_ENUM(NSInteger, TOIPCCommandType) {
  TOIPCCommandTypeInfo = 0,
  TOIPCCommandTypeSplit = 1,
  TOIPCCommandTypeCustom = 99
};

// ==================== 核心接口 ====================

/// 确保 IPC 目录存在
void TOIPCEnsureDir(void);

/// 原子写 plist
BOOL TOIPCWritePlist(NSDictionary *dict);

/// 读取 plist
NSDictionary *_Nullable TOIPCReadPlist(void);

/// 发送 Darwin 通知
void TOIPCSendDarwin(NSString *name);

// ==================== 命令队列 API ====================

/// 入队命令（带自动 UUID 和时间戳）
/// @param type 命令类型
/// @param payload 命令载荷（如 bundleId、info 等）
/// @return 命令 UUID（用于追踪）
NSString *_Nullable TOIPCEnqueueCommand(TOIPCCommandType type,
                                        NSDictionary *payload);

/// 读取待处理命令队列
/// @return 命令数组，每个元素包含 uuid/type/payload/ts
NSArray<NSDictionary *> *_Nullable TOIPCDequeueCommands(void);

/// 标记命令已处理（ACK），用于去重
/// @param uuid 命令 UUID
void TOIPCMarkProcessed(NSString *uuid);

/// 检查命令是否已处理
/// @param uuid 命令 UUID
/// @return YES = 已处理，应跳过
BOOL TOIPCIsProcessed(NSString *uuid);

/// 清理已处理记录（可选，定期调用）
void TOIPCCleanupProcessed(NSTimeInterval olderThan);

// ==================== 便捷 API（保留向后兼容） ====================

/// 发送 info 命令（简化版，使用队列）
void TOIPCSendInfo(NSString *info);

/// 发送 splitId 命令（简化版，使用队列）
void TOIPCSendSplitId(NSString *bundleIdOrSplitId);

__END_DECLS

NS_ASSUME_NONNULL_END
