#import "UNTISLesson.h"
#import "UNTISStyle.h"

// JSON helpers: values can be NSNull / NSNumber / NSString, never trust them.
NSInteger UNTISInt(id v) {
    return ([v isKindOfClass:[NSNumber class]] || [v isKindOfClass:[NSString class]]) ? [v integerValue] : 0;
}
NSString *UNTISStr(id v) {
    if ([v isKindOfClass:[NSString class]]) return v;
    if ([v isKindOfClass:[NSNumber class]]) return [v stringValue];
    return nil;
}
static NSString *Key(NSInteger i) { return [NSString stringWithFormat:@"%ld", (long)i]; }
static NSInteger ToMinutes(NSInteger hhmm) { return (hhmm / 100) * 60 + hhmm % 100; }

// Reads te / ro / su / kl arrays of a period.
static NSDictionary *ReadElements(id els, NSDictionary *map) {
    NSMutableArray *names = [NSMutableArray array], *longs = [NSMutableArray array], *origs = [NSMutableArray array];
    BOOL changed = NO;
    NSString *firstKey = nil;
    if ([els isKindOfClass:[NSArray class]]) {
        for (id e in els) {
            if (![e isKindOfClass:[NSDictionary class]]) continue;
            NSInteger eid = UNTISInt(e[@"id"]), oid = UNTISInt(e[@"orgid"]);
            NSString *nm = UNTISStr(e[@"name"]), *lg = UNTISStr(e[@"longname"]);
            NSDictionary *m = eid ? map[Key(eid)] : nil;
            if (!nm.length) nm = m[@"name"];
            if (!lg.length) lg = m[@"long"];
            if (oid && oid != eid) {
                changed = YES;
                NSString *on = ((NSDictionary *)map[Key(oid)])[@"name"];
                if (on.length) [origs addObject:on];
            }
            if (!nm.length) continue;
            [names addObject:nm];
            [longs addObject:lg.length ? lg : nm];
            if (!firstKey && eid) firstKey = Key(eid);
        }
    }
    return @{@"names": names, @"longs": longs, @"origs": origs, @"changed": @(changed), @"key": firstKey ? firstKey : @""};
}

static NSString *Join(NSDictionary *d, NSString *k) {
    NSString *s = [(NSArray *)d[k] componentsJoinedByString:@", "];
    return s ? s : @"";
}

@implementation UNTISLesson

- (BOOL)changed { return self.irregular || self.teacherChanged || self.roomChanged; }

+ (NSArray *)lessonsFromJSON:(NSArray *)json master:(NSDictionary *)master {
    NSDictionary *sMap = master[@"subjects"], *rMap = master[@"rooms"], *tMap = master[@"teachers"];
    NSMutableArray *out = [NSMutableArray array];
    for (id item in json) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSDictionary *p = item;
        UNTISLesson *l = [[UNTISLesson alloc] init];
        l.date = UNTISInt(p[@"date"]);
        l.startMin = ToMinutes(UNTISInt(p[@"startTime"]));
        l.endMin = ToMinutes(UNTISInt(p[@"endTime"]));
        NSString *code = UNTISStr(p[@"code"]);
        l.cancelled = [code isEqualToString:@"cancelled"];
        l.irregular = [code isEqualToString:@"irregular"];
        l.exam = [UNTISStr(p[@"lstype"]) isEqualToString:@"ex"];

        NSDictionary *su = ReadElements(p[@"su"], sMap);
        NSDictionary *te = ReadElements(p[@"te"], tMap);
        NSDictionary *ro = ReadElements(p[@"ro"], rMap);
        NSDictionary *kl = ReadElements(p[@"kl"], @{});
        l.subject = Join(su, @"names");
        l.subjectLong = Join(su, @"longs");
        l.teachers = Join(te, @"names");
        l.teachersLong = Join(te, @"longs");
        l.origTeachers = Join(te, @"origs");
        l.rooms = Join(ro, @"names");
        l.roomsLong = Join(ro, @"longs");
        l.origRooms = Join(ro, @"origs");
        l.classes = Join(kl, @"names");
        l.teacherChanged = [te[@"changed"] boolValue];
        l.roomChanged = [ro[@"changed"] boolValue];

        NSString *sk = su[@"key"];
        UIColor *c = sk.length ? [UNTISStyle colorFromHex:((NSDictionary *)sMap[sk])[@"color"]] : nil;
        l.color = c ? c : [UNTISStyle colorForSubject:l.subject];

        NSMutableArray *texts = [NSMutableArray array];
        for (NSString *k in @[@"lstext", @"substText", @"info"]) {
            NSString *t = UNTISStr(p[k]);
            if (t.length && ![texts containsObject:t]) [texts addObject:t];
        }
        l.info = [texts componentsJoinedByString:@"\n"];
        [out addObject:l];
    }
    [out sortUsingComparator:^NSComparisonResult(UNTISLesson *a, UNTISLesson *b) {
        if (a.date != b.date) return a.date < b.date ? NSOrderedAscending : NSOrderedDescending;
        if (a.startMin != b.startMin) return a.startMin < b.startMin ? NSOrderedAscending : NSOrderedDescending;
        return NSOrderedSame;
    }];
    return out;
}

@end
