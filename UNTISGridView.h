#import <UIKit/UIKit.h>
#import "UNTISLesson.h"

// Day names + dates row (stays fixed while the grid scrolls)
@interface UNTISGridHeaderView : UIView
@property (nonatomic, strong) NSDate *weekStart;
@property (nonatomic) NSInteger dayCount;
@property (nonatomic) CGFloat timeColumnWidth;
@end

// Week grid: time column + one column per day, lessons drawn as colored blocks
@interface UNTISGridView : UIView
@property (nonatomic, strong) NSDate *weekStart;
@property (nonatomic, copy) NSArray *lessons;
@property (nonatomic, copy) NSArray *timegrid;
@property (nonatomic) CGFloat timeColumnWidth;
@property (nonatomic) CGFloat pointsPerMinute;
@property (nonatomic, readonly) NSInteger dayCount, rangeStart, rangeEnd;
@property (nonatomic, copy) void (^onSelect)(UNTISLesson *lesson);

- (void)reload;   // recompute day count and visible time range
@end
