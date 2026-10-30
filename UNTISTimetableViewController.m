#import "UNTISTimetableViewController.h"
#import "UNTISGridView.h"
#import "UNTISAPI.h"
#import "UNTISStyle.h"
#import "UNTISLessonDetailViewController.h"

static const CGFloat kHeaderH = 54, kBannerH = 26;

@interface UNTISTimetableViewController ()
@property (nonatomic, strong) UNTISGridHeaderView *header;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UNTISGridView *grid;
@property (nonatomic, strong) UILabel *banner;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIRefreshControl *refresh;
@property (nonatomic, strong) NSDate *weekStart;
@property (nonatomic, copy) NSArray *lessons;
@property (nonatomic) NSInteger token;
@end

@implementation UNTISTimetableViewController

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.view.backgroundColor = [UIColor whiteColor];
    self.weekStart = [UNTISStyle mondayOfWeekContaining:[NSDate date]];

    self.scroll = [[UIScrollView alloc] init];
    self.scroll.alwaysBounceVertical = YES;
    self.scroll.directionalLockEnabled = YES;
    [self.view addSubview:self.scroll];

    self.grid = [[UNTISGridView alloc] initWithFrame:CGRectZero];
    __weak typeof(self) weakSelf = self;
    self.grid.onSelect = ^(UNTISLesson *l) { [UNTISLessonDetailViewController presentLesson:l from:weakSelf]; };
    [self.scroll addSubview:self.grid];

    self.header = [[UNTISGridHeaderView alloc] init];
    [self.view addSubview:self.header];

    self.refresh = [[UIRefreshControl alloc] init];
    [self.refresh addTarget:self action:@selector(loadWeek) forControlEvents:UIControlEventValueChanged];
    [self.scroll addSubview:self.refresh];

    self.banner = [[UILabel alloc] init];
    self.banner.font = [UIFont systemFontOfSize:13];
    self.banner.textAlignment = NSTextAlignmentCenter;
    self.banner.textColor = [UIColor whiteColor];
    self.banner.backgroundColor = [UNTISStyle changeColor];
    self.banner.hidden = YES;
    [self.view addSubview:self.banner];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];

    UIBarButtonItem *prev = [[UIBarButtonItem alloc] initWithTitle:@"‹" style:UIBarButtonItemStylePlain target:self action:@selector(prevWeek)];
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"›" style:UIBarButtonItemStylePlain target:self action:@selector(nextWeek)];
    NSDictionary *big = @{NSFontAttributeName: [UIFont systemFontOfSize:34]};
    [prev setTitleTextAttributes:big forState:UIControlStateNormal];
    [next setTitleTextAttributes:big forState:UIControlStateNormal];
    self.navigationItem.leftBarButtonItems = @[prev, next];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:Loc(@"today") style:UIBarButtonItemStylePlain
                                                                             target:self action:@selector(goToday)];

    UISwipeGestureRecognizer *left = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(nextWeek)];
    left.direction = UISwipeGestureRecognizerDirectionLeft;
    UISwipeGestureRecognizer *right = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(prevWeek)];
    right.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:left];
    [self.view addGestureRecognizer:right];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appBecameActive)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
    [self applyLessons];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadWeek];
}

- (void)appBecameActive {
    if (self.isViewLoaded && self.view.window) [self loadWeek];
}

#pragma mark - Navigation

- (void)shiftWeeks:(NSInteger)n {
    self.weekStart = [UNTISStyle addDays:7 * n toDate:self.weekStart];
    self.lessons = @[];
    [self applyLessons];
    [self loadWeek];
}
- (void)prevWeek { [self shiftWeeks:-1]; }
- (void)nextWeek { [self shiftWeeks:1]; }
- (void)goToday {
    self.weekStart = [UNTISStyle mondayOfWeekContaining:[NSDate date]];
    self.lessons = @[];
    [self applyLessons];
    [self loadWeek];
}

#pragma mark - Data

- (void)loadWeek {
    NSInteger tok = ++self.token;
    NSInteger s = [UNTISStyle dateIntFromDate:self.weekStart];
    NSInteger e = [UNTISStyle dateIntFromDate:[UNTISStyle addDays:6 toDate:self.weekStart]];
    if (!self.lessons.count) [self.spinner startAnimating];
    [[UNTISAPI shared] fetchLessonsFrom:s to:e completion:^(NSArray *lessons, BOOL fromCache, NSError *err) {
        if (tok != self.token) return;
        if (lessons) { self.lessons = lessons; [self applyLessons]; }
        if (!fromCache) {
            [self.refresh endRefreshing];
            [self.spinner stopAnimating];
            if (err) [self showBanner:(self.lessons.count ? Loc(@"offline") : err.localizedDescription)];
            else [self showBanner:nil];
        }
    }];
}

- (void)showBanner:(NSString *)text {
    self.banner.text = text;
    self.banner.hidden = (text == nil);
    [self.view setNeedsLayout];
}

- (void)applyLessons {
    self.grid.weekStart = self.weekStart;
    self.grid.lessons = self.lessons;
    self.grid.timegrid = [[UNTISAPI shared] timegrid];
    [self.grid reload];
    self.header.weekStart = self.weekStart;
    self.header.dayCount = self.grid.dayCount;
    [self.header setNeedsDisplay];
    NSDate *last = [UNTISStyle addDays:self.grid.dayCount - 1 toDate:self.weekStart];
    self.navigationItem.title = [NSString stringWithFormat:@"%@ – %@",
        [[UNTISStyle formatterWithTemplate:@"d MMM"] stringFromDate:self.weekStart],
        [[UNTISStyle formatterWithTemplate:@"d MMM yyyy"] stringFromDate:last]];
    [self.view setNeedsLayout];
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat W = self.view.bounds.size.width, H = self.view.bounds.size.height, y = 0;
    if (!self.banner.hidden) { self.banner.frame = CGRectMake(0, 0, W, kBannerH); y = kBannerH; }
    self.header.frame = CGRectMake(0, y, W, kHeaderH);
    y += kHeaderH;
    self.scroll.frame = CGRectMake(0, y, W, H - y);
    self.spinner.center = CGPointMake(W / 2, y + (H - y) / 2);

    CGFloat range = MAX(60, self.grid.rangeEnd - self.grid.rangeStart);
    CGFloat ppm = MAX(1.0, (self.scroll.bounds.size.height - 2) / range);   // fill the screen, scroll if longer
    self.grid.pointsPerMinute = ppm;
    self.grid.frame = CGRectMake(0, 0, W, ceil(range * ppm) + 2);
    self.scroll.contentSize = self.grid.frame.size;
    [self.grid setNeedsDisplay];
    [self.header setNeedsDisplay];
}

@end
