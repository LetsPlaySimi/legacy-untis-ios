#import "UNTISGridView.h"
#import "UNTISStyle.h"

static NSDictionary *Attrs(UIFont *font, UIColor *color, NSTextAlignment align, BOOL strike) {
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.alignment = align;
    ps.lineBreakMode = NSLineBreakByTruncatingTail;
    NSMutableDictionary *d = [@{NSFontAttributeName: font, NSForegroundColorAttributeName: color,
                                NSParagraphStyleAttributeName: ps} mutableCopy];
    if (strike) d[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
    return d;
}

#pragma mark - Header

@implementation UNTISGridHeaderView

- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor whiteColor];
        self.contentMode = UIViewContentModeRedraw;
        _dayCount = 5;
        _timeColumnWidth = 56;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat dayW = (self.bounds.size.width - self.timeColumnWidth) / MAX(1, self.dayCount);
    NSInteger todayInt = [UNTISStyle dateIntFromDate:[NSDate date]];

    if (self.weekStart) {
        NSInteger week = [[UNTISStyle calendar] component:NSCalendarUnitWeekOfYear fromDate:self.weekStart];
        NSString *w = [NSString stringWithFormat:@"%@ %ld", Loc(@"week_abbr"), (long)week];
        [w drawInRect:CGRectMake(0, 19, self.timeColumnWidth, 16)
       withAttributes:Attrs([UIFont systemFontOfSize:11], [UNTISStyle textSecondary], NSTextAlignmentCenter, NO)];
    }
    for (NSInteger d = 0; d < self.dayCount; d++) {
        NSDate *date = [UNTISStyle addDays:d toDate:self.weekStart];
        BOOL today = [UNTISStyle dateIntFromDate:date] == todayInt;
        CGFloat x = self.timeColumnWidth + d * dayW;
        NSString *name = [[[UNTISStyle formatterWithTemplate:@"EEE"] stringFromDate:date] uppercaseString];
        [name drawInRect:CGRectMake(x, 7, dayW, 14)
          withAttributes:Attrs([UIFont boldSystemFontOfSize:11], today ? [UNTISStyle accent] : [UNTISStyle textSecondary], NSTextAlignmentCenter, NO)];
        CGRect circle = CGRectMake(x + dayW / 2 - 14, 22, 28, 28);
        UIColor *numColor = [UNTISStyle textPrimary];
        if (today) {
            [[UNTISStyle accent] setFill];
            CGContextFillEllipseInRect(c, circle);
            numColor = [UIColor whiteColor];
        }
        NSString *num = [[UNTISStyle formatterWithTemplate:@"d"] stringFromDate:date];
        [num drawInRect:CGRectMake(circle.origin.x, circle.origin.y + 5, 28, 20)
         withAttributes:Attrs([UIFont boldSystemFontOfSize:16], numColor, NSTextAlignmentCenter, NO)];
    }
    [[UNTISStyle line] setFill];
    CGContextFillRect(c, CGRectMake(0, self.bounds.size.height - 1, self.bounds.size.width, 1));
}

@end

#pragma mark - Grid

@interface UNTISGridView ()
@property (nonatomic, strong) NSArray *units;            // @{name,start,end}
@property (nonatomic, strong) NSMutableArray *blockLessons;
@property (nonatomic, strong) NSMutableArray *blockRects;
@end

@implementation UNTISGridView

- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor whiteColor];
        self.opaque = YES;
        self.contentMode = UIViewContentModeRedraw;
        _timeColumnWidth = 56;
        _pointsPerMinute = 1.0;
        _dayCount = 5;
        _rangeStart = 8 * 60;
        _rangeEnd = 15 * 60;
        _blockLessons = [NSMutableArray array];
        _blockRects = [NSMutableArray array];
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)]];
    }
    return self;
}

- (NSArray *)lessonsOnDay:(NSInteger)day {
    NSInteger di = [UNTISStyle dateIntFromDate:[UNTISStyle addDays:day toDate:self.weekStart]];
    NSMutableArray *out = [NSMutableArray array];
    for (UNTISLesson *l in self.lessons) if (l.date == di) [out addObject:l];
    return out;
}

- (void)reload {
    // weekend columns only when something happens there
    NSInteger days = 5;
    for (NSInteger d = 5; d < 7; d++) if ([self lessonsOnDay:d].count) days = d + 1;
    _dayCount = days;

    // period rows: school grid, or derived from the lessons
    NSMutableArray *units = [NSMutableArray array];
    if (self.timegrid.count) {
        [units addObjectsFromArray:self.timegrid];
    } else {
        NSMutableSet *seen = [NSMutableSet set];
        NSArray *sorted = [self.lessons sortedArrayUsingComparator:^NSComparisonResult(UNTISLesson *a, UNTISLesson *b) {
            return a.startMin < b.startMin ? NSOrderedAscending : (a.startMin > b.startMin ? NSOrderedDescending : NSOrderedSame);
        }];
        for (UNTISLesson *l in sorted) {
            NSString *k = [NSString stringWithFormat:@"%ld-%ld", (long)l.startMin, (long)l.endMin];
            if ([seen containsObject:k]) continue;
            [seen addObject:k];
            [units addObject:@{@"name": [NSString stringWithFormat:@"%lu", (unsigned long)units.count + 1],
                               @"start": @(l.startMin), @"end": @(l.endMin)}];
        }
    }
    self.units = units;

    NSInteger lo = NSIntegerMax, hi = 0;
    for (NSDictionary *u in units) {
        lo = MIN(lo, [u[@"start"] integerValue]);
        hi = MAX(hi, [u[@"end"] integerValue]);
    }
    for (UNTISLesson *l in self.lessons) { lo = MIN(lo, l.startMin); hi = MAX(hi, l.endMin); }
    if (lo == NSIntegerMax || hi <= lo) { lo = 8 * 60; hi = 15 * 60; }
    _rangeStart = lo;
    _rangeEnd = hi;
    [self setNeedsDisplay];
}

- (CGFloat)dayWidth { return (self.bounds.size.width - self.timeColumnWidth) / MAX(1, self.dayCount); }
- (CGFloat)yForMinute:(NSInteger)m { return (m - self.rangeStart) * self.pointsPerMinute; }

// Places lessons of one day; overlapping lessons share the column width.
- (void)placeCluster:(NSArray *)cluster day:(NSInteger)day {
    NSMutableArray *colEnds = [NSMutableArray array];
    NSMutableArray *cols = [NSMutableArray array];
    for (UNTISLesson *l in cluster) {
        NSInteger col = -1;
        for (NSUInteger i = 0; i < colEnds.count; i++) {
            if ([colEnds[i] integerValue] <= l.startMin) { col = i; break; }
        }
        if (col < 0) { [colEnds addObject:@0]; col = colEnds.count - 1; }
        colEnds[col] = @(l.endMin);
        [cols addObject:@(col)];
    }
    CGFloat dayW = [self dayWidth];
    CGFloat w = dayW / colEnds.count;
    for (NSUInteger i = 0; i < cluster.count; i++) {
        UNTISLesson *l = cluster[i];
        CGFloat x = self.timeColumnWidth + day * dayW + [cols[i] integerValue] * w + 2;
        CGFloat y = [self yForMinute:l.startMin] + 1;
        CGFloat h = (l.endMin - l.startMin) * self.pointsPerMinute - 2;
        [self.blockLessons addObject:l];
        [self.blockRects addObject:[NSValue valueWithCGRect:CGRectMake(x, y, w - 4, MAX(h, 8))]];
    }
}

- (void)layoutBlocks {
    [self.blockLessons removeAllObjects];
    [self.blockRects removeAllObjects];
    for (NSInteger d = 0; d < self.dayCount; d++) {
        NSMutableArray *cluster = [NSMutableArray array];
        NSInteger clusterEnd = -1;
        for (UNTISLesson *l in [self lessonsOnDay:d]) {
            if (cluster.count && l.startMin >= clusterEnd) {
                [self placeCluster:cluster day:d];
                [cluster removeAllObjects];
                clusterEnd = -1;
            }
            [cluster addObject:l];
            clusterEnd = MAX(clusterEnd, l.endMin);
        }
        if (cluster.count) [self placeCluster:cluster day:d];
    }
}

- (void)drawRect:(CGRect)rect {
    [self layoutBlocks];
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height;
    CGFloat tcw = self.timeColumnWidth, dayW = [self dayWidth];
    NSInteger todayInt = [UNTISStyle dateIntFromDate:[NSDate date]];
    NSInteger todayCol = -1;

    [[UIColor whiteColor] setFill];
    CGContextFillRect(c, self.bounds);

    for (NSInteger d = 0; d < self.dayCount; d++) {
        if ([UNTISStyle dateIntFromDate:[UNTISStyle addDays:d toDate:self.weekStart]] == todayInt) {
            todayCol = d;
            [[[UNTISStyle accent] colorWithAlphaComponent:0.06] setFill];
            CGContextFillRect(c, CGRectMake(tcw + d * dayW, 0, dayW, H));
        }
    }

    // period rows
    UIColor *grey = [UNTISStyle textSecondary];
    for (NSDictionary *u in self.units) {
        NSInteger s = [u[@"start"] integerValue], e = [u[@"end"] integerValue];
        CGFloat y0 = [self yForMinute:s], y1 = [self yForMinute:e];
        [[UNTISStyle line] setFill];
        CGContextFillRect(c, CGRectMake(0, y0, W, 1));
        CGContextFillRect(c, CGRectMake(0, y1, W, 1));
        [[UNTISStyle timeString:s] drawInRect:CGRectMake(0, y0 + 3, tcw, 12)
            withAttributes:Attrs([UIFont systemFontOfSize:9], grey, NSTextAlignmentCenter, NO)];
        if (y1 - y0 > 34)
            [[UNTISStyle timeString:e] drawInRect:CGRectMake(0, y1 - 14, tcw, 12)
                withAttributes:Attrs([UIFont systemFontOfSize:9], grey, NSTextAlignmentCenter, NO)];
        [u[@"name"] drawInRect:CGRectMake(0, (y0 + y1) / 2 - 9, tcw, 18)
            withAttributes:Attrs([UIFont boldSystemFontOfSize:14], [UNTISStyle textPrimary], NSTextAlignmentCenter, NO)];
    }
    // column separators
    [[UNTISStyle line] setFill];
    for (NSInteger d = 0; d <= self.dayCount; d++) CGContextFillRect(c, CGRectMake(tcw + d * dayW - 0.5, 0, 1, H));

    // lessons
    for (NSUInteger i = 0; i < self.blockLessons.count; i++) {
        UNTISLesson *l = self.blockLessons[i];
        CGRect r = [self.blockRects[i] CGRectValue];
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:4];
        UIColor *fill = l.color ? l.color : [UIColor colorWithWhite:0.92 alpha:1];
        UIColor *textColor = [UNTISStyle isLight:fill] ? [UNTISStyle textPrimary] : [UIColor whiteColor];
        if (l.cancelled) {
            fill = [fill colorWithAlphaComponent:0.30];
            textColor = [UNTISStyle textSecondary];
        }
        [fill setFill];
        [path fill];
        if (l.cancelled) {   // diagonal hatching
            CGContextSaveGState(c);
            [path addClip];
            [[UIColor colorWithWhite:0.5 alpha:0.35] setStroke];
            CGContextSetLineWidth(c, 1);
            for (CGFloat x = r.origin.x - r.size.height; x < CGRectGetMaxX(r); x += 7) {
                CGContextMoveToPoint(c, x, CGRectGetMaxY(r));
                CGContextAddLineToPoint(c, x + r.size.height, r.origin.y);
            }
            CGContextStrokePath(c);
            CGContextRestoreGState(c);
        }
        if (l.changed && !l.cancelled) {
            UIBezierPath *border = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(r, 1, 1) cornerRadius:3.5];
            border.lineWidth = 2;
            [[UNTISStyle changeColor] setStroke];
            [border stroke];
        }

        // text lines
        BOOL big = r.size.height >= 44;
        UIFont *f1 = big ? [UIFont boldSystemFontOfSize:14] : [UIFont boldSystemFontOfSize:11];
        UIFont *f2 = [UIFont systemFontOfSize:big ? 11 : 10];
        NSMutableArray *lines = [NSMutableArray array];   // @[text, font, color, bold?]
        UIColor *chg = [UNTISStyle changeColor];
        if (r.size.height >= 30) {
            [lines addObject:@[l.subject, f1, textColor]];
            if (l.teachers.length)
                [lines addObject:@[l.teachers, l.teacherChanged && !l.cancelled ? [UIFont boldSystemFontOfSize:f2.pointSize] : f2,
                                   l.teacherChanged && !l.cancelled ? chg : textColor]];
            if (l.rooms.length && r.size.height >= 48)
                [lines addObject:@[l.rooms, l.roomChanged && !l.cancelled ? [UIFont boldSystemFontOfSize:f2.pointSize] : f2,
                                   l.roomChanged && !l.cancelled ? chg : textColor]];
            else if (l.rooms.length && lines.count == 2 && r.size.height < 48) {
                // too small for a third line: put teacher and room on one line
                NSString *both = [NSString stringWithFormat:@"%@ · %@", l.teachers, l.rooms];
                [lines replaceObjectAtIndex:1 withObject:@[both, f2, textColor]];
            }
        } else {
            NSString *one = l.rooms.length ? [NSString stringWithFormat:@"%@ %@", l.subject, l.rooms] : l.subject;
            [lines addObject:@[one, f2, textColor]];
        }
        CGFloat total = 0;
        for (NSArray *ln in lines) total += ceil([ln[1] lineHeight]);
        CGFloat y = r.origin.y + MAX(1, (r.size.height - total) / 2);
        for (NSArray *ln in lines) {
            CGFloat lh = ceil([ln[1] lineHeight]);
            [ln[0] drawInRect:CGRectMake(r.origin.x + 3, y, r.size.width - 6, lh)
               withAttributes:Attrs(ln[1], ln[2], NSTextAlignmentCenter, l.cancelled)];
            y += lh;
        }
    }

    // current time marker
    if (todayCol >= 0) {
        NSInteger now = [UNTISStyle minutesNow];
        if (now >= self.rangeStart && now <= self.rangeEnd) {
            CGFloat y = [self yForMinute:now];
            UIColor *red = [UIColor colorWithRed:0.9 green:0.22 blue:0.21 alpha:1];
            [red setFill];
            CGContextFillRect(c, CGRectMake(tcw + todayCol * dayW, y - 0.75, dayW, 1.5));
            CGContextFillEllipseInRect(c, CGRectMake(tcw + todayCol * dayW - 4, y - 4, 8, 8));
        }
    }
}

- (void)tapped:(UITapGestureRecognizer *)g {
    CGPoint p = [g locationInView:self];
    for (NSInteger i = (NSInteger)self.blockRects.count - 1; i >= 0; i--) {
        if (CGRectContainsPoint([self.blockRects[i] CGRectValue], p)) {
            if (self.onSelect) self.onSelect(self.blockLessons[i]);
            return;
        }
    }
}

@end
