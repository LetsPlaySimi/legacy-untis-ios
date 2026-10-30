#import "UNTISStyle.h"

NSString *Loc(NSString *key) {
    static NSDictionary *en, *de;
    static BOOL useDe;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        useDe = [[[NSLocale preferredLanguages] firstObject] hasPrefix:@"de"];
        en = @{
            @"login_sub": @"Legacy client for iOS 8",
            @"server": @"Server (e.g. school.webuntis.com)",
            @"school": @"School short name",
            @"user": @"Username",
            @"password": @"Password",
            @"login": @"Log In",
            @"login_failed": @"Login failed",
            @"fill_all": @"Please fill in all fields.",
            @"bad_server": @"The server address is invalid.",
            @"ok": @"OK",
            @"cancel": @"Cancel",
            @"today": @"Today",
            @"timetable": @"Timetable",
            @"profile": @"Profile",
            @"logout": @"Log Out",
            @"logout_q": @"Do you want to log out? Saved data will be deleted.",
            @"no_lessons": @"No lessons today",
            @"cancelled": @"Cancelled",
            @"substitution": @"Substitution",
            @"exam": @"Exam",
            @"lesson": @"Lesson",
            @"time": @"Time",
            @"subject": @"Subject",
            @"teacher": @"Teacher",
            @"room": @"Room",
            @"klasse": @"Class",
            @"status": @"Status",
            @"info": @"Info",
            @"done": @"Done",
            @"offline": @"Offline – showing saved data",
            @"n_lessons": @"%ld lessons",
            @"n_cancelled": @"%ld cancelled",
            @"now": @"Now",
            @"week_abbr": @"W",
            @"account": @"Account",
            @"user_row": @"User",
            @"school_row": @"School",
            @"server_row": @"Server",
            @"instead_of": @"%@ (instead of %@)"
        };
        de = @{
            @"login_sub": @"Legacy-Client für iOS 8",
            @"server": @"Server (z. B. schule.webuntis.com)",
            @"school": @"Schul-Kurzname",
            @"user": @"Benutzername",
            @"password": @"Passwort",
            @"login": @"Anmelden",
            @"login_failed": @"Anmeldung fehlgeschlagen",
            @"fill_all": @"Bitte alle Felder ausfüllen.",
            @"bad_server": @"Die Serveradresse ist ungültig.",
            @"ok": @"OK",
            @"cancel": @"Abbrechen",
            @"today": @"Heute",
            @"timetable": @"Stundenplan",
            @"profile": @"Profil",
            @"logout": @"Abmelden",
            @"logout_q": @"Möchtest du dich abmelden? Gespeicherte Daten werden gelöscht.",
            @"no_lessons": @"Heute kein Unterricht",
            @"cancelled": @"Entfällt",
            @"substitution": @"Vertretung",
            @"exam": @"Prüfung",
            @"lesson": @"Unterricht",
            @"time": @"Zeit",
            @"subject": @"Fach",
            @"teacher": @"Lehrkraft",
            @"room": @"Raum",
            @"klasse": @"Klasse",
            @"status": @"Status",
            @"info": @"Info",
            @"done": @"Fertig",
            @"offline": @"Offline – gespeicherte Daten",
            @"n_lessons": @"%ld Stunden",
            @"n_cancelled": @"%ld entfallen",
            @"now": @"Jetzt",
            @"week_abbr": @"KW",
            @"account": @"Konto",
            @"user_row": @"Benutzer",
            @"school_row": @"Schule",
            @"server_row": @"Server",
            @"instead_of": @"%@ (statt %@)"
        };
    });
    NSString *s = (useDe ? de : en)[key];
    return s ? s : key;
}

@implementation UNTISStyle

+ (UIColor *)accent        { return [UIColor colorWithRed:0.961 green:0.510 blue:0.125 alpha:1]; }
+ (UIColor *)changeColor   { return [UIColor colorWithRed:0.902 green:0.318 blue:0.0 alpha:1]; }
+ (UIColor *)cancelColor   { return [UIColor colorWithRed:0.827 green:0.184 blue:0.184 alpha:1]; }
+ (UIColor *)background    { return [UIColor colorWithRed:0.949 green:0.949 blue:0.969 alpha:1]; }
+ (UIColor *)line          { return [UIColor colorWithRed:0.89 green:0.89 blue:0.91 alpha:1]; }
+ (UIColor *)textPrimary   { return [UIColor colorWithRed:0.11 green:0.11 blue:0.118 alpha:1]; }
+ (UIColor *)textSecondary { return [UIColor colorWithRed:0.43 green:0.43 blue:0.45 alpha:1]; }

+ (UIColor *)colorFromHex:(NSString *)hex {
    if (![hex isKindOfClass:[NSString class]]) return nil;
    hex = [hex stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"# \n"]];
    if (hex.length != 6) return nil;
    unsigned int v = 0;
    if (![[NSScanner scannerWithString:hex] scanHexInt:&v]) return nil;
    if (v == 0xFFFFFF) return nil;   // "white" = unset in most schools
    return [UIColor colorWithRed:((v >> 16) & 0xFF) / 255.0 green:((v >> 8) & 0xFF) / 255.0 blue:(v & 0xFF) / 255.0 alpha:1];
}

+ (UIColor *)colorForSubject:(NSString *)name {
    NSString *u = [[name uppercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!u.length) return [UIColor colorWithWhite:0.9 alpha:1];
    NSString *first = [[u componentsSeparatedByString:@" "] firstObject];
    // same hints as the old web client: Deutsch = pink, Mathe = yellow, Englisch = blue
    if ([first isEqualToString:@"D"] || [u hasPrefix:@"DEUTSCH"]) return [self colorFromHex:@"F8BBD0"];
    if ([first isEqualToString:@"M"] || [u hasPrefix:@"MATHE"])   return [self colorFromHex:@"FFF59D"];
    if ([first isEqualToString:@"E"] || [u hasPrefix:@"ENGLISCH"]) return [self colorFromHex:@"90CAF9"];
    NSArray *palette = @[@"A5D6A7", @"FFCC80", @"CE93D8", @"80DEEA", @"E6EE9C", @"BCAAA4",
                         @"B0BEC5", @"FFAB91", @"9FA8DA", @"80CBC4", @"F48FB1", @"C5E1A5"];
    NSUInteger h = 5381;
    for (NSUInteger i = 0; i < first.length; i++) h = h * 33 + [first characterAtIndex:i];
    return [self colorFromHex:palette[h % palette.count]];
}

+ (BOOL)isLight:(UIColor *)color {
    CGFloat r = 1, g = 1, b = 1, a = 1;
    [color getRed:&r green:&g blue:&b alpha:&a];
    return (0.299 * r + 0.587 * g + 0.114 * b) > 0.6;
}

+ (UIImage *)tabIcon:(NSString *)name {
    CGFloat s = 28;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(s, s), NO, 0);
    [[UIColor blackColor] setStroke];
    UIBezierPath *p = [UIBezierPath bezierPath];
    p.lineWidth = 2;
    p.lineCapStyle = kCGLineCapRound;
    if ([name isEqualToString:@"today"]) {
        [p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(4, 4, 20, 20)]];
        [p moveToPoint:CGPointMake(14, 14)]; [p addLineToPoint:CGPointMake(14, 8)];
        [p moveToPoint:CGPointMake(14, 14)]; [p addLineToPoint:CGPointMake(18.5, 16.5)];
    } else if ([name isEqualToString:@"timetable"]) {
        [p appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 5, 20, 19) cornerRadius:3]];
        [p moveToPoint:CGPointMake(4, 11)];  [p addLineToPoint:CGPointMake(24, 11)];
        [p moveToPoint:CGPointMake(11, 11)]; [p addLineToPoint:CGPointMake(11, 24)];
        [p moveToPoint:CGPointMake(17.5, 11)]; [p addLineToPoint:CGPointMake(17.5, 24)];
        [p moveToPoint:CGPointMake(4, 17.5)]; [p addLineToPoint:CGPointMake(24, 17.5)];
    } else {
        [p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9, 4, 10, 10)]];
        [p appendPath:[UIBezierPath bezierPathWithArcCenter:CGPointMake(14, 25) radius:10
                                                 startAngle:M_PI endAngle:2 * M_PI clockwise:YES]];
    }
    [p stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - Dates

+ (NSCalendar *)calendar {
    static NSCalendar *cal;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        cal.firstWeekday = 2;
        cal.minimumDaysInFirstWeek = 4;   // ISO week numbers
    });
    return cal;
}

+ (NSInteger)dateIntFromDate:(NSDate *)date {
    NSDateComponents *c = [[self calendar] components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:date];
    return c.year * 10000 + c.month * 100 + c.day;
}

+ (NSDate *)dateFromInt:(NSInteger)value {
    NSDateComponents *c = [[NSDateComponents alloc] init];
    c.year = value / 10000; c.month = (value / 100) % 100; c.day = value % 100; c.hour = 12;
    return [[self calendar] dateFromComponents:c];
}

+ (NSDate *)addDays:(NSInteger)days toDate:(NSDate *)date {
    NSDateComponents *c = [[NSDateComponents alloc] init];
    c.day = days;
    return [[self calendar] dateByAddingComponents:c toDate:date options:0];
}

+ (NSDate *)mondayOfWeekContaining:(NSDate *)date {
    NSDate *noon = [self dateFromInt:[self dateIntFromDate:date]];
    NSInteger weekday = [[self calendar] component:NSCalendarUnitWeekday fromDate:noon];  // 1 = Sunday
    return [self addDays:-((weekday + 5) % 7) toDate:noon];
}

+ (NSInteger)minutesNow {
    NSDateComponents *c = [[self calendar] components:(NSCalendarUnitHour | NSCalendarUnitMinute) fromDate:[NSDate date]];
    return c.hour * 60 + c.minute;
}

+ (NSString *)timeString:(NSInteger)minutes {
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)(minutes / 60), (long)(minutes % 60)];
}

+ (NSDateFormatter *)formatterWithTemplate:(NSString *)tpl {
    static NSMutableDictionary *cache;
    if (!cache) cache = [NSMutableDictionary dictionary];
    NSDateFormatter *f = cache[tpl];
    if (!f) {
        f = [[NSDateFormatter alloc] init];
        f.locale = [NSLocale currentLocale];
        f.calendar = [self calendar];
        f.dateFormat = [NSDateFormatter dateFormatFromTemplate:tpl options:0 locale:f.locale];
        cache[tpl] = f;
    }
    return f;
}

@end
