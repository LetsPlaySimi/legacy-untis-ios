#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSInteger UNTISInt(id v);
FOUNDATION_EXPORT NSString *UNTISStr(id v);

@interface UNTISLesson : NSObject
@property (nonatomic) NSInteger date;        // yyyymmdd
@property (nonatomic) NSInteger startMin;    // minutes since midnight
@property (nonatomic) NSInteger endMin;
@property (nonatomic, copy) NSString *subject, *subjectLong;
@property (nonatomic, copy) NSString *teachers, *teachersLong, *origTeachers;
@property (nonatomic, copy) NSString *rooms, *roomsLong, *origRooms;
@property (nonatomic, copy) NSString *classes;
@property (nonatomic, copy) NSString *info;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic) BOOL cancelled, irregular, exam, teacherChanged, roomChanged;

- (BOOL)changed;
// master: @{subjects, rooms, teachers} -> @{ "<id>": @{name, long, color} }
+ (NSArray *)lessonsFromJSON:(NSArray *)json master:(NSDictionary *)master;
@end
