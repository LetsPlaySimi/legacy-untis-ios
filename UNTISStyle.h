#import <UIKit/UIKit.h>

// Localized string (English / German, chosen from the device language).
NSString *Loc(NSString *key);

@interface UNTISStyle : NSObject

// Colors (change the accent here to re-theme the whole app)
+ (UIColor *)accent;
+ (UIColor *)changeColor;
+ (UIColor *)cancelColor;
+ (UIColor *)background;
+ (UIColor *)line;
+ (UIColor *)textPrimary;
+ (UIColor *)textSecondary;
+ (UIColor *)colorFromHex:(NSString *)hex;          // nil if invalid or white
+ (UIColor *)colorForSubject:(NSString *)name;      // fallback colors
+ (BOOL)isLight:(UIColor *)color;
+ (UIImage *)tabIcon:(NSString *)name;              // today / timetable / profile

// Dates. All "day" dates are at 12:00 local time to avoid DST problems.
+ (NSCalendar *)calendar;
+ (NSInteger)dateIntFromDate:(NSDate *)date;        // yyyymmdd
+ (NSDate *)dateFromInt:(NSInteger)value;
+ (NSDate *)addDays:(NSInteger)days toDate:(NSDate *)date;
+ (NSDate *)mondayOfWeekContaining:(NSDate *)date;
+ (NSInteger)minutesNow;
+ (NSString *)timeString:(NSInteger)minutes;       // "08:05"
+ (NSDateFormatter *)formatterWithTemplate:(NSString *)tpl;

@end
