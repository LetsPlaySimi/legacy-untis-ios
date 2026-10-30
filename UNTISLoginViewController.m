#import "UNTISLoginViewController.h"
#import "UNTISAPI.h"
#import "UNTISStyle.h"

@interface UNTISLoginViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIView *container;
@property (nonatomic, strong) UILabel *logo, *sub;
@property (nonatomic, strong) NSArray *fields;   // server, school, user, password
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic) CGFloat keyboardTop;       // y of the keyboard in our view, or large when hidden
@end

@implementation UNTISLoginViewController

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (UITextField *)fieldWithPlaceholder:(NSString *)ph secure:(BOOL)secure {
    UITextField *f = [[UITextField alloc] init];
    f.backgroundColor = [UIColor whiteColor];
    f.layer.cornerRadius = 8;
    f.layer.borderWidth = 1;
    f.layer.borderColor = [UNTISStyle line].CGColor;
    f.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 10)];
    f.leftViewMode = UITextFieldViewModeAlways;
    f.font = [UIFont systemFontOfSize:17];
    f.textColor = [UNTISStyle textPrimary];
    f.placeholder = ph;
    f.secureTextEntry = secure;
    f.autocorrectionType = UITextAutocorrectionTypeNo;
    f.autocapitalizationType = UITextAutocapitalizationTypeNone;
    f.clearButtonMode = UITextFieldViewModeWhileEditing;
    f.returnKeyType = UIReturnKeyNext;
    f.delegate = self;
    [self.container addSubview:f];
    return f;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UNTISStyle background];
    self.keyboardTop = 100000;
    self.container = [[UIView alloc] init];
    [self.view addSubview:self.container];

    self.logo = [[UILabel alloc] init];
    self.logo.text = @"Untis";
    self.logo.font = [UIFont boldSystemFontOfSize:48];
    self.logo.textColor = [UNTISStyle accent];
    self.logo.textAlignment = NSTextAlignmentCenter;
    [self.container addSubview:self.logo];
    self.sub = [[UILabel alloc] init];
    self.sub.text = Loc(@"login_sub");
    self.sub.font = [UIFont systemFontOfSize:14];
    self.sub.textColor = [UNTISStyle textSecondary];
    self.sub.textAlignment = NSTextAlignmentCenter;
    [self.container addSubview:self.sub];

    UITextField *server = [self fieldWithPlaceholder:Loc(@"server") secure:NO];
    server.keyboardType = UIKeyboardTypeURL;
    UITextField *school = [self fieldWithPlaceholder:Loc(@"school") secure:NO];
    UITextField *user = [self fieldWithPlaceholder:Loc(@"user") secure:NO];
    UITextField *pw = [self fieldWithPlaceholder:Loc(@"password") secure:YES];
    pw.returnKeyType = UIReturnKeyGo;
    self.fields = @[server, school, user, pw];

    UNTISAPI *api = [UNTISAPI shared];
    server.text = api.server; school.text = api.school; user.text = api.user;

    self.button = [UIButton buttonWithType:UIButtonTypeCustom];
    self.button.backgroundColor = [UNTISStyle accent];
    self.button.layer.cornerRadius = 8;
    self.button.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.button setTitle:Loc(@"login") forState:UIControlStateNormal];
    [self.button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.button addTarget:self action:@selector(login) forControlEvents:UIControlEventTouchUpInside];
    [self.container addSubview:self.button];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.spinner.hidesWhenStopped = YES;
    [self.container addSubview:self.spinner];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self.view action:@selector(endEditing:)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardChanged:)
                                                 name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)positionContainerAnimated:(BOOL)animated duration:(NSTimeInterval)dur {
    CGFloat W = self.view.bounds.size.width, H = self.view.bounds.size.height;
    CGFloat cw = MIN(420, W - 40), ch = 140 + 4 * 58 + 64;
    CGFloat y = (H - ch) / 2;
    CGFloat overlap = (y + ch + 16) - self.keyboardTop;
    if (overlap > 0) y = MAX(8, y - overlap);
    void (^apply)(void) = ^{ self.container.frame = CGRectMake((W - cw) / 2, y, cw, ch); };
    if (animated) [UIView animateWithDuration:dur animations:apply]; else apply();
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat cw = MIN(420, self.view.bounds.size.width - 40);
    self.logo.frame = CGRectMake(0, 10, cw, 58);
    self.sub.frame = CGRectMake(0, 70, cw, 20);
    CGFloat y = 110;
    for (UITextField *f in self.fields) { f.frame = CGRectMake(0, y, cw, 48); y += 58; }
    self.button.frame = CGRectMake(0, y + 6, cw, 52);
    self.spinner.center = CGPointMake(cw - 36, y + 6 + 26);
    [self positionContainerAnimated:NO duration:0];
}

- (void)keyboardChanged:(NSNotification *)n {
    CGRect kb = [[n.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    kb = [self.view convertRect:kb fromView:nil];
    self.keyboardTop = (kb.origin.y >= self.view.bounds.size.height) ? 100000 : kb.origin.y;
    NSTimeInterval dur = [[n.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [self positionContainerAnimated:YES duration:dur];
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    NSUInteger i = [self.fields indexOfObject:tf];
    if (i + 1 < self.fields.count) [self.fields[i + 1] becomeFirstResponder];
    else [self login];
    return NO;
}

- (void)setBusy:(BOOL)busy {
    self.view.userInteractionEnabled = !busy;
    self.button.alpha = busy ? 0.7 : 1;
    if (busy) [self.spinner startAnimating]; else [self.spinner stopAnimating];
}

- (void)login {
    NSMutableArray *v = [NSMutableArray array];
    for (UITextField *f in self.fields) {
        [v addObject:[f.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
    for (NSString *s in v) if (!s.length) { [self showError:Loc(@"fill_all")]; return; }
    [self.view endEditing:YES];
    [self setBusy:YES];
    [[UNTISAPI shared] loginWithServer:v[0] school:v[1] user:v[2] password:[self.fields[3] text] completion:^(NSError *err) {
        [self setBusy:NO];
        if (err) [self showError:err.localizedDescription];   // on success the app delegate swaps the screen
    }];
}

- (void)showError:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:Loc(@"login_failed") message:msg
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:Loc(@"ok") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
