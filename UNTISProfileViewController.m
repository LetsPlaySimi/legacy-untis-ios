#import "UNTISProfileViewController.h"
#import "UNTISAPI.h"
#import "UNTISStyle.h"

@implementation UNTISProfileViewController

- (instancetype)init { return [super initWithStyle:UITableViewStyleGrouped]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = Loc(@"profile");
    self.tableView.backgroundColor = [UNTISStyle background];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 2; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 0 ? 3 : 1; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return s == 0 ? Loc(@"account") : nil; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UNTISAPI *api = [UNTISAPI shared];
    if (ip.section == 0) {
        NSArray *labels = @[Loc(@"user_row"), Loc(@"school_row"), Loc(@"server_row")];
        NSArray *values = @[api.user ? api.user : @"", api.school ? api.school : @"", api.server ? api.server : @""];
        cell.textLabel.text = labels[ip.row];
        cell.detailTextLabel.text = values[ip.row];
    } else {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = Loc(@"logout");
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [UNTISStyle cancelColor];
    }
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != 1) return;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:Loc(@"logout") message:Loc(@"logout_q")
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:Loc(@"cancel") style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:Loc(@"logout") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
        [[UNTISAPI shared] logout];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
