#import "UNTISAPI.h"
#import "UNTISLesson.h"
#import "UNTISStyle.h"
#import <Security/Security.h>

NSString *const UNTISSessionDidChangeNotification = @"UNTISSessionDidChange";

static NSString *const kKeychainService = @"legacy.untis";
static NSString *Key(NSInteger i) { return [NSString stringWithFormat:@"%ld", (long)i]; }

@interface UNTISAPI ()
@property (nonatomic, strong) NSURLSession *http;
@property (nonatomic, copy) NSString *sessionId;
@property (nonatomic) NSInteger personId, personType;
@property (nonatomic, strong) NSMutableDictionary *master;
@property (nonatomic) BOOL masterLoaded, masterLoading, authenticating;
@property (nonatomic, strong) NSMutableArray *masterWaiters, *sessionWaiters;
@property (nonatomic, copy) NSString *cacheDir;
@end

@implementation UNTISAPI

+ (instancetype)shared {
    static UNTISAPI *api;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ api = [[UNTISAPI alloc] init]; });
    return api;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 20;
        cfg.HTTPShouldSetCookies = NO;
        cfg.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
        _http = [NSURLSession sessionWithConfiguration:cfg];
        _masterWaiters = [NSMutableArray array];
        _sessionWaiters = [NSMutableArray array];
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        _server = [d stringForKey:@"untis.server"];
        _school = [d stringForKey:@"untis.school"];
        _user = [d stringForKey:@"untis.user"];
        NSString *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
        _cacheDir = [caches stringByAppendingPathComponent:@"untis"];
        [[NSFileManager defaultManager] createDirectoryAtPath:_cacheDir withIntermediateDirectories:YES attributes:nil error:nil];
        id saved = [self readJSON:@"master"];
        _master = [saved isKindOfClass:[NSDictionary class]] ? [saved mutableCopy] : [NSMutableDictionary dictionary];
    }
    return self;
}

#pragma mark - Settings / credentials

- (void)setServer:(NSString *)s { _server = [s copy]; [[NSUserDefaults standardUserDefaults] setObject:s forKey:@"untis.server"]; }
- (void)setSchool:(NSString *)s { _school = [s copy]; [[NSUserDefaults standardUserDefaults] setObject:s forKey:@"untis.school"]; }
- (void)setUser:(NSString *)s   { _user = [s copy];   [[NSUserDefaults standardUserDefaults] setObject:s forKey:@"untis.user"]; }

- (BOOL)hasCredentials {
    return self.server.length && self.school.length && self.user.length && [self savedPassword].length;
}

// Keychain first; falls back to NSUserDefaults when the app has no keychain entitlement (common on jailbroken ad-hoc installs).
- (NSDictionary *)keychainQuery {
    return @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
             (__bridge id)kSecAttrService: kKeychainService,
             (__bridge id)kSecAttrAccount: @"password"};
}

- (void)storePassword:(NSString *)pw {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSDictionary *q = [self keychainQuery];
    SecItemDelete((__bridge CFDictionaryRef)q);
    NSMutableDictionary *add = [q mutableCopy];
    add[(__bridge id)kSecValueData] = [pw dataUsingEncoding:NSUTF8StringEncoding];
    OSStatus st = SecItemAdd((__bridge CFDictionaryRef)add, NULL);
    if (st == errSecSuccess) [d removeObjectForKey:@"untis.pw"];
    else [d setObject:pw forKey:@"untis.pw"];
}

- (NSString *)savedPassword {
    NSMutableDictionary *q = [[self keychainQuery] mutableCopy];
    q[(__bridge id)kSecReturnData] = @YES;
    q[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef out = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)q, &out) == errSecSuccess && out) {
        NSData *data = CFBridgingRelease(out);
        NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (s.length) return s;
    }
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"untis.pw"];
}

- (void)deletePassword {
    SecItemDelete((__bridge CFDictionaryRef)[self keychainQuery]);
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"untis.pw"];
}

#pragma mark - Disk cache

- (NSString *)pathFor:(NSString *)name { return [self.cacheDir stringByAppendingPathComponent:[name stringByAppendingString:@".json"]]; }

- (id)readJSON:(NSString *)name {
    NSData *d = [NSData dataWithContentsOfFile:[self pathFor:name]];
    return d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] : nil;
}

- (void)writeJSON:(id)obj name:(NSString *)name {
    if (![NSJSONSerialization isValidJSONObject:obj]) return;
    NSData *d = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
    [d writeToFile:[self pathFor:name] atomically:YES];
}

- (void)clearCache {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *f in [fm contentsOfDirectoryAtPath:self.cacheDir error:nil])
        [fm removeItemAtPath:[self.cacheDir stringByAppendingPathComponent:f] error:nil];
    self.master = [NSMutableDictionary dictionary];
    self.masterLoaded = NO;
}

#pragma mark - JSON-RPC

- (NSError *)errorWithCode:(NSInteger)code message:(NSString *)msg {
    return [NSError errorWithDomain:@"UNTIS" code:code userInfo:@{NSLocalizedDescriptionKey: msg.length ? msg : @"Error"}];
}

- (NSURL *)endpointURL {
    NSString *s = [self.server stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSRange r = [s rangeOfString:@"/WebUntis" options:NSCaseInsensitiveSearch];
    if (r.location != NSNotFound) s = [s substringToIndex:r.location];
    while ([s hasSuffix:@"/"]) s = [s substringToIndex:s.length - 1];
    if (!s.length) return nil;
    NSString *low = [s lowercaseString];
    if (![low hasPrefix:@"http://"] && ![low hasPrefix:@"https://"]) s = [@"https://" stringByAppendingString:s];
    NSMutableCharacterSet *ok = [NSMutableCharacterSet alphanumericCharacterSet];
    [ok addCharactersInString:@"-._~"];
    NSString *school = [(self.school ? self.school : @"") stringByAddingPercentEncodingWithAllowedCharacters:ok];
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/WebUntis/jsonrpc.do?school=%@", s, school]];
}

// One request, no session handling.
- (void)rawCall:(NSString *)method params:(id)params completion:(void (^)(id result, NSError *err))block {
    NSURL *url = [self endpointURL];
    if (!url) {
        NSError *e = [self errorWithCode:-1 message:Loc(@"bad_server")];
        dispatch_async(dispatch_get_main_queue(), ^{ block(nil, e); });
        return;
    }
    NSDictionary *body = @{@"id": @"1", @"method": method, @"params": params ? params : @{}, @"jsonrpc": @"2.0"};
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    req.HTTPShouldHandleCookies = NO;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"UntisLegacy/1.0 (iOS 8)" forHTTPHeaderField:@"User-Agent"];
    if (self.sessionId.length) [req setValue:[@"JSESSIONID=" stringByAppendingString:self.sessionId] forHTTPHeaderField:@"Cookie"];

    [[self.http dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *netErr) {
        id result = nil;
        NSError *err = netErr;
        if (!err) {
            NSInteger status = [resp isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)resp statusCode] : 0;
            id json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            if ([json isKindOfClass:[NSDictionary class]]) {
                id eo = json[@"error"];
                if ([eo isKindOfClass:[NSDictionary class]])
                    err = [self errorWithCode:UNTISInt(eo[@"code"]) message:UNTISStr(eo[@"message"])];
                else
                    result = json[@"result"] ? json[@"result"] : [NSNull null];
            } else {
                err = [self errorWithCode:status message:[NSString stringWithFormat:@"HTTP %ld", (long)status]];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ block(result, err); });
    }] resume];
}

- (void)authenticateWithPassword:(NSString *)pw completion:(void (^)(NSError *))block {
    self.sessionId = nil;
    NSDictionary *params = @{@"user": self.user ? self.user : @"", @"password": pw ? pw : @"", @"client": @"UntisLegacy"};
    [self rawCall:@"authenticate" params:params completion:^(id result, NSError *err) {
        if (!err) {
            NSString *sid = [result isKindOfClass:[NSDictionary class]] ? UNTISStr(result[@"sessionId"]) : nil;
            if (sid.length) {
                self.sessionId = sid;
                self.personId = UNTISInt(result[@"personId"]);
                self.personType = UNTISInt(result[@"personType"]);
            } else {
                err = [self errorWithCode:-1 message:@"Invalid server response"];
            }
        }
        block(err);
    }];
}

- (void)ensureSession:(void (^)(NSError *))block {
    if (self.sessionId.length) { block(nil); return; }
    [self.sessionWaiters addObject:[block copy]];
    if (self.authenticating) return;
    self.authenticating = YES;
    [self authenticateWithPassword:[self savedPassword] completion:^(NSError *err) {
        self.authenticating = NO;
        NSArray *waiters = [self.sessionWaiters copy];
        [self.sessionWaiters removeAllObjects];
        if (err && err.code == -8504) [self logout];   // password no longer valid -> back to login
        for (void (^w)(NSError *) in waiters) w(err);
    }];
}

// Session-aware call: logs in on demand and retries once if the session expired.
- (void)call:(NSString *)method params:(id)params completion:(void (^)(id, NSError *))block {
    [self ensureSession:^(NSError *serr) {
        if (serr) { block(nil, serr); return; }
        NSString *used = self.sessionId;
        [self rawCall:method params:params completion:^(id result, NSError *err) {
            if (err && err.code == -8520) {   // not authenticated
                if ([self.sessionId isEqualToString:used]) self.sessionId = nil;
                [self ensureSession:^(NSError *serr2) {
                    if (serr2) { block(nil, serr2); return; }
                    [self rawCall:method params:params completion:block];
                }];
                return;
            }
            block(result, err);
        }];
    }];
}

#pragma mark - Login / logout

- (void)loginWithServer:(NSString *)server school:(NSString *)school user:(NSString *)user
               password:(NSString *)password completion:(void (^)(NSError *))block {
    self.server = server; self.school = school; self.user = user;
    [self authenticateWithPassword:password completion:^(NSError *err) {
        if (err) { block(err); return; }
        [self clearCache];
        [self storePassword:password];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[NSNotificationCenter defaultCenter] postNotificationName:UNTISSessionDidChangeNotification object:nil];
        block(nil);
    }];
}

- (void)logout {
    if (self.sessionId.length) [self rawCall:@"logout" params:@{} completion:^(id r, NSError *e) {}];
    self.sessionId = nil;
    self.personId = 0;
    [self deletePassword];
    [self clearCache];
    [[NSNotificationCenter defaultCenter] postNotificationName:UNTISSessionDidChangeNotification object:nil];
}

#pragma mark - Master data (subjects, rooms, teachers, period grid)

- (NSDictionary *)mapFromArray:(NSArray *)arr teachers:(BOOL)isTeacher {
    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    for (id o in arr) {
        if (![o isKindOfClass:[NSDictionary class]]) continue;
        NSString *name = UNTISStr(o[@"name"]);
        NSString *lg = UNTISStr(o[@"longName"]);
        if (!lg.length) lg = UNTISStr(o[@"longname"]);
        if (isTeacher) {
            NSString *fn = UNTISStr(o[@"foreName"]);
            if (lg.length && fn.length) lg = [NSString stringWithFormat:@"%@ %@", fn, lg];
        }
        NSMutableDictionary *e = [NSMutableDictionary dictionary];
        if (name) e[@"name"] = name;
        if (lg.length) e[@"long"] = lg;
        NSString *bc = UNTISStr(o[@"backColor"]);
        if (bc.length) e[@"color"] = bc;
        m[Key(UNTISInt(o[@"id"]))] = e;
    }
    return m;
}

- (NSArray *)gridFromJSON:(NSArray *)days {
    NSArray *best = nil;
    for (id d in days) {
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        NSArray *units = d[@"timeUnits"];
        if ([units isKindOfClass:[NSArray class]] && units.count > best.count) best = units;
    }
    NSMutableArray *out = [NSMutableArray array];
    for (id u in best) {
        if (![u isKindOfClass:[NSDictionary class]]) continue;
        NSInteger s = UNTISInt(u[@"startTime"]), e = UNTISInt(u[@"endTime"]);
        NSString *name = UNTISStr(u[@"name"]);
        [out addObject:@{@"name": name ? name : @"",
                         @"start": @((s / 100) * 60 + s % 100),
                         @"end": @((e / 100) * 60 + e % 100)}];
    }
    return out;
}

- (NSArray *)timegrid {
    id g = self.master[@"timegrid"];
    return [g isKindOfClass:[NSArray class]] ? g : @[];
}

- (void)loadMaster:(void (^)(void))block {
    if (self.masterLoaded) { block(); return; }
    [self.masterWaiters addObject:[block copy]];
    if (self.masterLoading) return;
    self.masterLoading = YES;
    NSMutableDictionary *fresh = [NSMutableDictionary dictionary];

    void (^finish)(void) = ^{
        for (NSString *k in fresh) self.master[k] = fresh[k];
        if (fresh.count) { self.masterLoaded = YES; [self writeJSON:self.master name:@"master"]; }
        self.masterLoading = NO;
        NSArray *w = [self.masterWaiters copy];
        [self.masterWaiters removeAllObjects];
        for (void (^b)(void) in w) b();
    };
    // Each call may fail (students often lack rights for some lists); that is fine.
    [self call:@"getSubjects" params:@{} completion:^(id r, NSError *e) {
        if ([r isKindOfClass:[NSArray class]]) fresh[@"subjects"] = [self mapFromArray:r teachers:NO];
        [self call:@"getRooms" params:@{} completion:^(id r2, NSError *e2) {
            if ([r2 isKindOfClass:[NSArray class]]) fresh[@"rooms"] = [self mapFromArray:r2 teachers:NO];
            [self call:@"getTeachers" params:@{} completion:^(id r3, NSError *e3) {
                if ([r3 isKindOfClass:[NSArray class]]) fresh[@"teachers"] = [self mapFromArray:r3 teachers:YES];
                [self call:@"getTimegridUnits" params:@{} completion:^(id r4, NSError *e4) {
                    if ([r4 isKindOfClass:[NSArray class]]) fresh[@"timegrid"] = [self gridFromJSON:r4];
                    finish();
                }];
            }];
        }];
    }];
}

#pragma mark - Timetable

- (void)fetchLessonsFrom:(NSInteger)start to:(NSInteger)end
              completion:(void (^)(NSArray *, BOOL, NSError *))block {
    NSString *file = [NSString stringWithFormat:@"tt_%ld_%ld", (long)start, (long)end];
    id cached = [self readJSON:file];
    if ([cached isKindOfClass:[NSArray class]])
        block([UNTISLesson lessonsFromJSON:cached master:self.master], YES, nil);

    void (^fetch)(void) = ^{
        [self ensureSession:^(NSError *serr) {
            if (serr) { block(nil, NO, serr); return; }
            NSArray *fields = @[@"id", @"name", @"longname"];
            NSDictionary *element = @{@"id": @(self.personId), @"type": @(self.personType)};
            NSDictionary *opts = @{@"id": @(self.personId), @"type": @(self.personType),
                                   @"element": element,
                                   @"startDate": @(start), @"endDate": @(end),
                                   @"showInfo": @YES, @"showSubstText": @YES, @"showLsText": @YES,
                                   @"klasseFields": fields, @"roomFields": fields,
                                   @"subjectFields": fields, @"teacherFields": fields};
            [self call:@"getTimetable" params:@{@"options": opts} completion:^(id result, NSError *err) {
                if (err) { block(nil, NO, err); return; }
                NSArray *arr = [result isKindOfClass:[NSArray class]] ? result : @[];
                [self writeJSON:arr name:file];
                block([UNTISLesson lessonsFromJSON:arr master:self.master], NO, nil);
            }];
        }];
    };

    if (self.masterLoaded || self.master.count) {
        fetch();                                   // use saved master data now, refresh it in the background
        if (!self.masterLoaded) [self loadMaster:^{}];
    } else {
        [self ensureSession:^(NSError *serr) {
            if (serr) { block(nil, NO, serr); return; }
            [self loadMaster:fetch];
        }];
    }
}

@end
