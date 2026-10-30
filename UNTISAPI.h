#import <Foundation/Foundation.h>

extern NSString *const UNTISSessionDidChangeNotification;

// Talks to the WebUntis JSON-RPC API directly (no proxy needed, native apps have no CORS).
@interface UNTISAPI : NSObject

+ (instancetype)shared;

@property (nonatomic, copy) NSString *server;   // persisted
@property (nonatomic, copy) NSString *school;   // persisted
@property (nonatomic, copy) NSString *user;     // persisted
@property (nonatomic, readonly) BOOL hasCredentials;

- (void)loginWithServer:(NSString *)server school:(NSString *)school user:(NSString *)user
               password:(NSString *)password completion:(void (^)(NSError *error))block;
- (void)logout;

// Calls block with cached lessons first (fromCache = YES, if any), then with fresh ones or an error.
// All callbacks happen on the main queue. Dates are yyyymmdd.
- (void)fetchLessonsFrom:(NSInteger)start to:(NSInteger)end
              completion:(void (^)(NSArray *lessons, BOOL fromCache, NSError *error))block;

// Array of @{name, start, end} (minutes) describing the school's period grid, may be empty.
- (NSArray *)timegrid;

@end
