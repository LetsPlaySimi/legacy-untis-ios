#import "UNTISTodayViewController.h"
#import "UNTISAPI.h"
#import "UNTISStyle.h"
#import "UNTISLessonDetailViewController.h"

#pragma mark - Cell

@interface UNTISLessonCell : UITableViewCell
@property (nonatomic, strong) UIView *card, *bar;
@property (nonatomic, strong) UILabel *startLabel, *endLabel, *titleLabel, *subLabel, *tagLabel;
- (void)configureWithLesson:(UNTISLesson *)l isNow:(BOOL)now;
@end

@implementation UNTISLessonCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if ((self = [super initWithStyle:style reuseIdentifier:rid])) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _card = [[UIView alloc] init];
        _card.backgroundColor = [UIColor whiteColor];
        _card.layer.cornerRadius = 8;
        _card.layer.borderWidth = 1;
        _card.layer.borderColor = [UNTISStyle line].CGColor;
        [self.contentView addSubview:_card];
        _bar = [[UIView alloc] init];
        [_card addSubview:_bar];
        _startLabel = [self labelWithFont:[UIFont boldSystemFontOfSize:16] color:[UNTISStyle textPrimary]];
        _endLabel = [self labelWithFont:[UIFont systemFontOfSize:13] color:[UNTISStyle textSecondary]];
        _startLabel.textAlignment = _endLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel = [self labelWithFont:[UIFont boldSystemFontOfSize:18] color:[UNTISStyle textPrimary]];
        _subLabel = [self labelWithFont:[UIFont systemFontOfSize:14] color:[UNTISStyle textSecondary]];
        _tagLabel = [self labelWithFont:[UIFont boldSystemFontOfSize:12] color:[UIColor whiteColor]];
        _tagLabel.textAlignment = NSTextAlignmentCenter;
        _tagLabel.layer.cornerRadius = 4;
        _tagLabel.clipsToBounds = YES;
    }
    return self;
}

- (UILabel *)labelWithFont:(UIFont *)f color:(UIColor *)c {
    UILabel *l = [[UILabel alloc] init];
    l.font = f; l.textColor = c; l.backgroundColor = [UIColor clearColor];
    [self.card addSubview:l];
    return l;
}

- (void)configureWithLesson:(UNTISLesson *)l isNow:(BOOL)now {
    self.startLabel.text = [UNTISStyle timeString:l.startMin];
    self.endLabel.text = [UNTISStyle timeString:l.endMin];
    self.bar.backgroundColor = l.color ? l.color : [UNTISStyle accent];
    NSString *title = l.subjectLong.length ? l.subjectLong : l.subject;
    NSDictionary *a = l.cancelled ? @{NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle)} : @{};
    self.titleLabel.attributedText = [[NSAttributedString alloc] initWithString:title ? title : @"" attributes:a];
    NSMutableArray *parts = [NSMutableArray array];
    if (l.teachers.length) [parts addObject:l.teachers];
    if (l.rooms.length) [parts addObject:l.rooms];
    self.subLabel.text = [parts componentsJoinedByString:@"  ·  "];
    NSString *tag = l.cancelled ? Loc(@"cancelled") : (l.changed ? Loc(@"substitution") : (l.exam ? Loc(@"exam") : (now ? Loc(@"now") : nil)));
    self.tagLabel.hidden = (tag == nil);
    self.tagLabel.text = tag;
    self.tagLabel.backgroundColor = l.cancelled ? [UNTISStyle cancelColor] : (l.changed ? [UNTISStyle changeColor] : [UNTISStyle accent]);
    self.card.layer.borderColor = (now ? [UNTISStyle accent] : [UNTISStyle line]).CGColor;
    self.card.layer.borderWidth = now ? 2 : 1;
    self.card.alpha = l.cancelled ? 0.7 : 1;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = MIN(self.contentView.bounds.size.width - 32, 680), H = self.contentView.bounds.size.height - 10;
    self.card.frame = CGRectMake((self.contentView.bounds.size.width - W) / 2, 5, W, H);
    self.startLabel.frame = CGRectMake(0, 14, 70, 22);
    self.endLabel.frame = CGRectMake(0, 38, 70, 18);
    self.bar.frame = CGRectMake(76, 10, 5, H - 20);
    self.bar.layer.cornerRadius = 2.5;
    CGFloat tagW = self.tagLabel.hidden ? 0 : 104;
    self.tagLabel.frame = CGRectMake(W - tagW - 14, 18, tagW, 22);
    self.titleLabel.frame = CGRectMake(96, 12, W - 96 - tagW - 24, 24);
    self.subLabel.frame = CGRectMake(96, 38, W - 110, 20);
}

@end

#pragma mark - Controller

@interface UNTISTodayViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UIView *head;
@property (nonatomic, strong) UILabel *dayLabel, *dateLabel, *summaryLabel, *emptyLabel, *banner;
@property (nonatomic, strong) UIRefreshControl *refresh;
@property (nonatomic, copy) NSArray *lessons;
@property (nonatomic) NSInteger token;
@end

@implementation UNTISTodayViewController

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.view.backgroundColor = [UNTISStyle background];
    self.navigationItem.title = Loc(@"today");

    self.table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.table.backgroundColor = [UNTISStyle background];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.rowHeight = 74;
    [self.view addSubview:self.table];

    self.head = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 104)];
    self.dayLabel = [self headLabel:[UIFont boldSystemFontOfSize:30] color:[UNTISStyle textPrimary] y:14 h:36];
    self.dateLabel = [self headLabel:[UIFont systemFontOfSize:16] color:[UNTISStyle textSecondary] y:50 h:22];
    self.summaryLabel = [self headLabel:[UIFont boldSystemFontOfSize:14] color:[UNTISStyle accent] y:74 h:22];
    self.table.tableHeaderView = self.head;

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.font = [UIFont systemFontOfSize:18];
    self.emptyLabel.textColor = [UNTISStyle textSecondary];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.text = Loc(@"no_lessons");
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];

    self.banner = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 26)];
    self.banner.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.banner.font = [UIFont systemFontOfSize:13];
    self.banner.textAlignment = NSTextAlignmentCenter;
    self.banner.textColor = [UIColor whiteColor];
    self.banner.backgroundColor = [UNTISStyle changeColor];
    self.banner.hidden = YES;
    [self.view addSubview:self.banner];

    self.refresh = [[UIRefreshControl alloc] init];
    [self.refresh addTarget:self action:@selector(load) forControlEvents:UIControlEventValueChanged];
    [self.table addSubview:self.refresh];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appBecameActive)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
    [self updateHeader];
}

- (UILabel *)headLabel:(UIFont *)f color:(UIColor *)c y:(CGFloat)y h:(CGFloat)h {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(24, y, 600, h)];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    l.font = f; l.textColor = c;
    [self.head addSubview:l];
    return l;
}

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self load]; }
- (void)appBecameActive { if (self.isViewLoaded && self.view.window) [self load]; }

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.head.frame = CGRectMake(0, 0, self.table.bounds.size.width, 104);
    self.table.tableHeaderView = self.head;
    self.emptyLabel.frame = CGRectMake(0, 130, self.view.bounds.size.width, 40);
}

- (void)updateHeader {
    NSDate *now = [NSDate date];
    self.dayLabel.text = [[UNTISStyle formatterWithTemplate:@"EEEE"] stringFromDate:now];
    self.dateLabel.text = [[UNTISStyle formatterWithTemplate:@"d MMMM yyyy"] stringFromDate:now];
    NSInteger cancelled = 0;
    for (UNTISLesson *l in self.lessons) if (l.cancelled) cancelled++;
    NSString *s = self.lessons.count ? [NSString stringWithFormat:Loc(@"n_lessons"), (long)self.lessons.count] : @"";
    if (cancelled) s = [NSString stringWithFormat:@"%@, %@", s, [NSString stringWithFormat:Loc(@"n_cancelled"), (long)cancelled]];
    self.summaryLabel.text = s;
}

- (void)load {
    NSInteger tok = ++self.token;
    NSInteger today = [UNTISStyle dateIntFromDate:[NSDate date]];
    [[UNTISAPI shared] fetchLessonsFrom:today to:today completion:^(NSArray *lessons, BOOL fromCache, NSError *err) {
        if (tok != self.token) return;
        if (lessons) {
            self.lessons = lessons;
            [self updateHeader];
            [self.table reloadData];
        }
        if (!fromCache) {
            [self.refresh endRefreshing];
            self.emptyLabel.hidden = (self.lessons.count > 0);
            self.banner.text = err ? (self.lessons.count ? Loc(@"offline") : err.localizedDescription) : nil;
            self.banner.hidden = (err == nil);
        }
    }];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return self.lessons.count; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UNTISLessonCell *cell = [tv dequeueReusableCellWithIdentifier:@"l"];
    if (!cell) cell = [[UNTISLessonCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"l"];
    UNTISLesson *l = self.lessons[ip.row];
    NSInteger now = [UNTISStyle minutesNow];
    [cell configureWithLesson:l isNow:(!l.cancelled && now >= l.startMin && now < l.endMin)];
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    [UNTISLessonDetailViewController presentLesson:self.lessons[ip.row] from:self];
}

@end
