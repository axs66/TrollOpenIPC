#import <UIKit/UIKit.h>
#import "../common/TOIPC.h"

// ==================== 悬浮按钮类 ====================

@interface TOFloatingButton : UIButton
@property (nonatomic, assign) CGPoint lastCenter;
@end

@implementation TOFloatingButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
        [self addGestureRecognizers];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.9];
    self.layer.cornerRadius = 25;
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 2);
    self.layer.shadowOpacity = 0.3;
    self.layer.shadowRadius = 4;
    
    [self setTitle:@"Split" forState:UIControlStateNormal];
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    
    [self addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
}

- (void)addGestureRecognizers {
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self addGestureRecognizer:pan];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *superview = self.superview;
    if (!superview) return;
    
    CGPoint translation = [gesture translationInView:superview];
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            self.lastCenter = self.center;
            break;
        case UIGestureRecognizerStateChanged: {
            CGPoint newCenter = CGPointMake(self.lastCenter.x + translation.x, self.lastCenter.y + translation.y);
            
            // 边界限制
            CGFloat halfWidth = self.bounds.size.width / 2;
            CGFloat halfHeight = self.bounds.size.height / 2;
            newCenter.x = MAX(halfWidth, MIN(superview.bounds.size.width - halfWidth, newCenter.x));
            newCenter.y = MAX(halfHeight, MIN(superview.bounds.size.height - halfHeight, newCenter.y));
            
            self.center = newCenter;
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            // 吸附到边缘
            [UIView animateWithDuration:0.25 animations:^{
                CGPoint center = self.center;
                CGFloat midX = superview.bounds.size.width / 2;
                CGFloat halfWidth = self.bounds.size.width / 2;
                
                if (center.x < midX) {
                    center.x = halfWidth + 10;
                } else {
                    center.x = superview.bounds.size.width - halfWidth - 10;
                }
                self.center = center;
            }];
            break;
        }
        default:
            break;
    }
}

- (void)buttonTapped {
    // 按钮点击动画
    [UIView animateWithDuration:0.1 animations:^{
        self.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
    }];
    
    // 发送分屏命令
    [self sendSplitCommand];
}

- (void)sendSplitCommand {
    // 获取当前 App 的 bundleId
    NSString *currentBundleId = [[NSBundle mainBundle] bundleIdentifier];
    
    // 示例：发送当前 App 与微信的分屏命令
    // 格式: "当前App|目标App"
    NSString *splitId = [NSString stringWithFormat:@"%@|com.tencent.xin", currentBundleId];
    
    TOIPCSendSplitId(splitId);
    
    NSLog(@"[TOIPC Sender] Sent split command: %@", splitId);
    
    // 显示反馈
    [self showFeedback:@"Split 命令已发送"];
}

- (void)showFeedback:(NSString *)message {
    UIView *superview = self.superview;
    if (!superview) return;
    
    UILabel *toast = [[UILabel alloc] init];
    toast.text = message;
    toast.textColor = [UIColor whiteColor];
    toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.font = [UIFont systemFontOfSize:14];
    toast.layer.cornerRadius = 8;
    toast.clipsToBounds = YES;
    toast.alpha = 0;
    
    [toast sizeToFit];
    toast.frame = CGRectMake(0, 0, toast.bounds.size.width + 24, toast.bounds.size.height + 12);
    toast.center = CGPointMake(superview.bounds.size.width / 2, superview.bounds.size.height - 100);
    
    [superview addSubview:toast];
    
    [UIView animateWithDuration:0.3 animations:^{
        toast.alpha = 1;
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{
                toast.alpha = 0;
            } completion:^(BOOL finished) {
                [toast removeFromSuperview];
            }];
        });
    }];
}

@end

// ==================== 全局悬浮按钮管理 ====================

static TOFloatingButton *sFloatingButton = nil;

static void EnsureFloatingButton(void) {
    if (sFloatingButton) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *window in scene.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                }
            }
        } else {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        if (!keyWindow) return;
        
        sFloatingButton = [[TOFloatingButton alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        sFloatingButton.center = CGPointMake(keyWindow.bounds.size.width - 35, keyWindow.bounds.size.height / 2);
        
        [keyWindow addSubview:sFloatingButton];
        NSLog(@"[TOIPC Sender] Floating button added");
    });
}

// ==================== Hook ====================

%hook UIApplication

- (void)applicationDidBecomeActive:(id)application {
    %orig;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            EnsureFloatingButton();
        });
    });
}

%end

// ==================== 构造器 ====================

%ctor {
    @autoreleasepool {
        NSLog(@"[TOIPC Sender] Loaded in %@", [[NSBundle mainBundle] bundleIdentifier]);
    }
}
