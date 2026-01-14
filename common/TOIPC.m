#import "TOIPC.h"
#import <notify.h>

// ==================== 常量定义 ====================
NSString *const kTOIPCDirPath = @"/var/mobile/TrollOpen";
NSString *const kTOIPCPlistPath =
    @"/var/mobile/TrollOpen/com.charlieleung.TrollOpen.plist";

NSString *const kTOIPCNotifyRequestInfo = @"TrollOpenRequestInfo";
NSString *const kTOIPCNotifyRequestSplitLayout = @"TrollOpenRequestSplitLayout";
NSString *const kTOIPCNotifyCommandQueued = @"TrollOpenCommandQueued";

// 已处理命令 ID 存储路径
static NSString *const kTOIPCProcessedPath =
    @"/var/mobile/TrollOpen/processed.plist";

// 防抖间隔（秒）
static const NSTimeInterval kDebounceInterval = 0.3;

// 最后发送时间（防抖）
static NSTimeInterval sLastSendTime = 0;

// ==================== 目录管理 ====================
void TOIPCEnsureDir(void) {
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL isDir = NO;
  if ([fm fileExistsAtPath:kTOIPCDirPath isDirectory:&isDir] && isDir)
    return;

  NSError *err = nil;
  [fm createDirectoryAtPath:kTOIPCDirPath
      withIntermediateDirectories:YES
                       attributes:@{
                         NSFilePosixPermissions : @(0777)
                       }
                            error:&err];
  if (err) {
    NSLog(@"[TOIPC] create dir error: %@", err);
  }
}

// ==================== Plist 读写 ====================
BOOL TOIPCWritePlist(NSDictionary *dict) {
  if (![dict isKindOfClass:[NSDictionary class]])
    return NO;
  TOIPCEnsureDir();

  NSError *error = nil;
  NSData *data = [NSPropertyListSerialization
      dataWithPropertyList:dict
                    format:NSPropertyListBinaryFormat_v1_0
                   options:0
                     error:&error];
  if (!data || error) {
    NSLog(@"[TOIPC] serialize plist failed: %@", error);
    return NO;
  }

  BOOL ok = [data writeToFile:kTOIPCPlistPath atomically:YES];
  if (!ok)
    NSLog(@"[TOIPC] write plist failed");
  return ok;
}

NSDictionary *_Nullable TOIPCReadPlist(void) {
  NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:kTOIPCPlistPath];
  return [d isKindOfClass:[NSDictionary class]] ? d : nil;
}

// ==================== Darwin 通知 ====================
void TOIPCSendDarwin(NSString *name) {
  if (name.length == 0)
    return;
  notify_post(name.UTF8String);
}

// ==================== 已处理记录管理 ====================
static NSMutableSet<NSString *> *sProcessedIds = nil;
static NSMutableDictionary<NSString *, NSNumber *> *sProcessedTimestamps = nil;

static void LoadProcessedIds(void) {
  if (sProcessedIds)
    return;

  sProcessedIds = [NSMutableSet new];
  sProcessedTimestamps = [NSMutableDictionary new];

  NSDictionary *dict =
      [NSDictionary dictionaryWithContentsOfFile:kTOIPCProcessedPath];
  if ([dict isKindOfClass:[NSDictionary class]]) {
    NSDictionary *timestamps = dict[@"timestamps"];
    if ([timestamps isKindOfClass:[NSDictionary class]]) {
      [sProcessedTimestamps addEntriesFromDictionary:timestamps];
      [sProcessedIds addObjectsFromArray:timestamps.allKeys];
    }
  }
}

static void SaveProcessedIds(void) {
  TOIPCEnsureDir();
  NSDictionary *dict = @{@"timestamps" : sProcessedTimestamps ?: @{}};
  [dict writeToFile:kTOIPCProcessedPath atomically:YES];
}

void TOIPCMarkProcessed(NSString *uuid) {
  if (uuid.length == 0)
    return;
  LoadProcessedIds();

  [sProcessedIds addObject:uuid];
  sProcessedTimestamps[uuid] = @([[NSDate date] timeIntervalSince1970]);
  SaveProcessedIds();
}

BOOL TOIPCIsProcessed(NSString *uuid) {
  if (uuid.length == 0)
    return NO;
  LoadProcessedIds();
  return [sProcessedIds containsObject:uuid];
}

void TOIPCCleanupProcessed(NSTimeInterval olderThan) {
  LoadProcessedIds();

  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  NSMutableArray *toRemove = [NSMutableArray new];

  for (NSString *uuid in sProcessedTimestamps) {
    NSTimeInterval ts = [sProcessedTimestamps[uuid] doubleValue];
    if (now - ts > olderThan) {
      [toRemove addObject:uuid];
    }
  }

  for (NSString *uuid in toRemove) {
    [sProcessedIds removeObject:uuid];
    [sProcessedTimestamps removeObjectForKey:uuid];
  }

  if (toRemove.count > 0) {
    SaveProcessedIds();
    NSLog(@"[TOIPC] cleaned up %lu old processed records",
          (unsigned long)toRemove.count);
  }
}

// ==================== 命令队列 ====================
NSString *_Nullable TOIPCEnqueueCommand(TOIPCCommandType type,
                                        NSDictionary *payload) {
  if (!payload)
    payload = @{};

  // 防抖检查
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  if (now - sLastSendTime < kDebounceInterval) {
    NSLog(@"[TOIPC] debounce: skipping command");
    return nil;
  }
  sLastSendTime = now;

  TOIPCEnsureDir();

  // 生成唯一 ID
  NSString *uuid = [[NSUUID UUID] UUIDString];

  // 构建命令
  NSDictionary *command = @{
    @"uuid" : uuid,
    @"type" : @(type),
    @"payload" : payload,
    @"ts" : @(now)
  };

  // 读取现有队列
  NSDictionary *plist = TOIPCReadPlist() ?: @{};
  NSMutableArray *queue =
      [NSMutableArray arrayWithArray:plist[@"queue"] ?: @[]];

  // 添加新命令
  [queue addObject:command];

  // 写回
  NSMutableDictionary *newPlist = [plist mutableCopy];
  newPlist[@"queue"] = queue;

  if (TOIPCWritePlist(newPlist)) {
    TOIPCSendDarwin(kTOIPCNotifyCommandQueued);
    NSLog(@"[TOIPC] enqueued command: type=%ld uuid=%@", (long)type, uuid);
    return uuid;
  }

  return nil;
}

NSArray<NSDictionary *> *_Nullable TOIPCDequeueCommands(void) {
  NSDictionary *plist = TOIPCReadPlist();
  if (!plist)
    return nil;

  NSArray *queue = plist[@"queue"];
  if (![queue isKindOfClass:[NSArray class]] || queue.count == 0) {
    return nil;
  }

  // 过滤已处理的命令
  NSMutableArray *pending = [NSMutableArray new];
  for (NSDictionary *cmd in queue) {
    NSString *uuid = cmd[@"uuid"];
    if (uuid && !TOIPCIsProcessed(uuid)) {
      [pending addObject:cmd];
    }
  }

  return pending.count > 0 ? pending : nil;
}

// ==================== 便捷 API ====================
void TOIPCSendInfo(NSString *info) {
  if (info.length == 0)
    return;
  TOIPCEnqueueCommand(TOIPCCommandTypeInfo, @{@"info" : info});
}

void TOIPCSendSplitId(NSString *bundleIdOrSplitId) {
  if (bundleIdOrSplitId.length == 0)
    return;
  TOIPCEnqueueCommand(TOIPCCommandTypeSplit, @{@"splitId" : bundleIdOrSplitId});
}
