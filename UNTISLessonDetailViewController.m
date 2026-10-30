#import "UNTISLessonDetailViewController.h"
#import "UNTISStyle.h"

@interface UNTISLessonDetailViewController ()
@property (nonatomic, strong) UNTISLesson *lesson;
@property (nonatomic, strong) NSArray *rows;   // @[label, value]
@end

@implementation UNTISLessonDetailViewController

+ (void)presentLesson:(UNTISLesson *)lesson from:(UIViewController *)parent {
    UNTISLessonDetailViewController *vc = [[self alloc] initWithLesson:lesson];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.navigationBar.translucent = NO;
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [parent presentViewController:nav animated:YES completion:nil];
}

- (instancetype)initWithLesson:(UNTISLesson *)lesson {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _lesson = lesson;
        self.preferredContentSize = CGSizeMake(460, 520);
    }
    return self;
}

- (NSString *)withOriginal:(NSString *)now orig:(NSString *)orig {
    if (!orig.length || [orig isEqualToString:now]) return now;
    return [NSString stringWithFormat:Loc(@"instead_of"), now.length ? now : @"–", orig];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UNTISLesson *l = self.lesson;
    self.navigationItem.title = Loc(@"lesson");
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self action:@selector(done)];
    self.tableView.backgroundColor = [UNTISStyle background];

    NSDate *day = [UNTISStyle dateFromInt:l.date];
    NSString *dayStr = [[UNTISStyle formatterWithTemplate:@"EEEE d MMMM"] stringFromDate:day];
    NSString *timeStr = [NSString stringWithFormat:@"%@ – %@", [UNTISStyle timeString:l.startMin], [UNTISStyle timeString:l.endMin]];

    NSMutableArray *rows = [NSMutableArray array];
    [rows addObject:@[Loc(@"time"), [NSString stringWithFormat:@"%@\n%@", dayStr, timeStr]]];
    if (l.subjectLong.length) [rows addObject:@[Loc(@"subject"), l.subjectLong]];
    if (l.teachers.length || l.origTeachers.length)
        [rows addObject:@[Loc(@"teacher"), [self withOriginal:l.teachersLong orig:l.origTeachers]]];
    if (l.rooms.length || l.origRooms.length)
        [rows addObject:@[Loc(@"room"), [self withOriginal:l.roomsLong orig:l.origRooms]]];
    if (l.classes.length) [rows addObject:@[Loc(@"klasse"), l.classes]];
    NSMutableArray *status = [NSMutableArray array];
    if (l.cancelled) [status addObject:Loc(@"cancelled")];
    else if (l.changed) [status addObject:Loc(@"substitution")];
    if (l.exam) [status addObject:Loc(@"exam")];
    if (status.count) [rows addObject:@[Loc(@"status"), [status componentsJoinedByString:@", "]]];
    if (l.info.length) [rows addObject:@[Loc(@"info"), l.info]];
    self.rows = rows;

    UIColor *bg = l.color ? l.color : [UNTISStyle accent];
    UIView *head = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 460, 84)];
    head.backgroundColor = bg;
    head.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIColor *tc = [UNTISStyle isLight:bg] ? [UNTISStyle textPrimary] : [UIColor whiteColor];
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(20, 14, 420, 32)];
    t.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    t.font = [UIFont boldSystemFontOfSize:24];
    t.textColor = tc;
    t.text = l.subjectLong.length ? l.subjectLong : l.subject;
    if (l.cancelled) t.attributedText = [[NSAttributedString alloc] initWithString:t.text
                                           attributes:@{NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle)}];
    [head addSubview:t];
    UILabel *s = [[UILabel alloc] initWithFrame:CGRectMake(20, 48, 420, 22)];
    s.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    s.font = [UIFont systemFontOfSize:15];
    s.textColor = tc;
    s.text = [NSString stringWithFormat:@"%@ · %@", [[UNTISStyle formatterWithTemplate:@"EEE d MMM"] stringFromDate:day], timeStr];
    [head addSubview:s];
    self.tableView.tableHeaderView = head;
}

- (void)done { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return self.rows.count; }

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    NSString *v = self.rows[ip.row][1];
    CGRect r = [v boundingRectWithSize:CGSizeMake(tv.bounds.size.width - 60, 1000)
                               options:NSStringDrawingUsesLineFragmentOrigin
                            attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:17]} context:nil];
    return ceil(r.size.height) + 40;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"d"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"d"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.font = [UIFont systemFontOfSize:12];
        cell.textLabel.textColor = [UNTISStyle textSecondary];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:17];
        cell.detailTextLabel.textColor = [UNTISStyle textPrimary];
        cell.detailTextLabel.numberOfLines = 0;
    }
    cell.textLabel.text = [self.rows[ip.row][0] uppercaseString];
    cell.detailTextLabel.text = self.rows[ip.row][1];
    return cell;
}

@end
