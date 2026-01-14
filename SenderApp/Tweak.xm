#import <UIKit/UIKit.h>
#import "../common/TOIPC.h"

// 示例：App 启动 2 秒后发一次 splitId（你也可以绑按钮/手势/设置开关触发）
%hook UIApplication
- (void)applicationDidBecomeActive:(id)application {
    %orig;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 例子：发 splitId
            TOIPCSendSplitId(@"com.tencent.xin"); // 你要的 bundleID / splitId

            // 例子：发 info
            TOIPCSendInfo(@"ping");
        });
    });
}
%end
