#import "UNTISRootViewController.h"
#import "UNTISTodayViewController.h"
#import "UNTISTimetableViewController.h"
#import "UNTISProfileViewController.h"
#import "UNTISStyle.h"

@implementation UNTISRootViewController

- (UINavigationController *)navWith:(UIViewController *)vc title:(NSString *)title icon:(NSString *)icon tag:(NSInteger)tag {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.navigationBar.translucent = NO;
    nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:Loc(title) image:[UNTISStyle tabIcon:icon] tag:tag];
    return nav;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.viewControllers = @[
        [self navWith:[[UNTISTodayViewController alloc] init] title:@"today" icon:@"today" tag:0],
        [self navWith:[[UNTISTimetableViewController alloc] init] title:@"timetable" icon:@"timetable" tag:1],
        [self navWith:[[UNTISProfileViewController alloc] init] title:@"profile" icon:@"profile" tag:2]
    ];
    self.tabBar.translucent = NO;
}

@end
