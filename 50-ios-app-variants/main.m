#import <UIKit/UIKit.h>

@interface VictimAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation VictimAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UIViewController *controller = [[UIViewController alloc] init];
    controller.view.backgroundColor = [UIColor systemBackgroundColor];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    NSLog(@"iOS app victim launched");
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([VictimAppDelegate class]));
    }
}
