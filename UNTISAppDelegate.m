#import "UNTISAppDelegate.h"
#import "UNTISAPI.h"
#import "UNTISStyle.h"
#import "UNTISRootViewController.h"
#import "UNTISLoginViewController.h"

@implementation UNTISAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.tintColor = [UNTISStyle accent];
    self.window.backgroundColor = [UIColor whiteColor];

    [[UINavigationBar appearance] setBarTintColor:[UIColor whiteColor]];
    [[UINavigationBar appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName: [UNTISStyle textPrimary],
                                                           NSFontAttributeName: [UIFont boldSystemFontOfSize:17]}];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionChanged)
                                                 name:UNTISSessionDidChangeNotification object:nil];
    self.window.rootViewController = [self makeRoot];
    [self.window makeKeyAndVisible];
    return YES;
}

- (UIViewController *)makeRoot {
    return [[UNTISAPI shared] hasCredentials] ? (UIViewController *)[[UNTISRootViewController alloc] init]
                                              : (UIViewController *)[[UNTISLoginViewController alloc] init];
}

- (void)sessionChanged {
    UIViewController *vc = [self makeRoot];
    [UIView transitionWithView:self.window duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{ self.window.rootViewController = vc; } completion:nil];
}

@end
