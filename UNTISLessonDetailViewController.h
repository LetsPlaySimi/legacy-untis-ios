#import <UIKit/UIKit.h>
#import "UNTISLesson.h"

@interface UNTISLessonDetailViewController : UITableViewController
- (instancetype)initWithLesson:(UNTISLesson *)lesson;
// Convenience: wraps in a navigation controller and presents as a form sheet.
+ (void)presentLesson:(UNTISLesson *)lesson from:(UIViewController *)parent;
@end
