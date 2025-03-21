//
//  ESFBMessaging.m
//  firebase
//
//  Created by Patryk Mol on 19.06.17.
//
//

#import "ESFBMessaging.h"
#import <FirebaseMessaging/FirebaseMessaging.h>
#import <FirebaseInstanceID/FirebaseInstanceID.h>
#import <UserNotifications/UserNotifications.h>
#import "ESFirebaseHelper.h"

@interface ESFBMessaging () <UNUserNotificationCenterDelegate, FIRMessagingDelegate>
@end

@implementation ESFBMessaging

@synthesize instanceId = _instanceId;
@synthesize token = _token;
@synthesize launchData = _launchData;
@synthesize tokenChangedListener = _tokenChangedListener;
@synthesize instanceIdChangedListener = _instanceIdChangedListener;
@synthesize messageListener = _messageListener;
@synthesize showBannersInForeground = _showBannersInForeground;

NSString *const kGCMMessageIDKey = @"gcm.message_id";
static NSDictionary *launchData;

- (instancetype)initWithObjectId:(NSString *)objectId properties:(NSDictionary *)properties inContext:(id<TabrisContext>)context {
    self = [super initWithObjectId:objectId properties:properties inContext:context];
    if (self) {
        [UNUserNotificationCenter currentNotificationCenter].delegate = self;
        [FIRMessaging messaging].delegate = self;
        [FIRMessaging messaging].shouldEstablishDirectChannel = YES;
        [self registerSelector:@selector(resetInstanceId) forCall:@"resetInstanceId"];
        [self registerSelector:@selector(registerForNotifications) forCall:@"requestPermissions"];
        [self registerSelector:@selector(getAllPendingMessages) forCall:@"getAllPendingMessages"];
        [self registerSelector:@selector(clearAllPendingMessages) forCall:@"clearAllPendingMessages"];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(instanceIdRefreshed:) name:kFIRInstanceIDTokenRefreshNotification object:nil];
    }
    return self;
}

- (void)destroy {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super destroy];
}

+ (NSMutableSet *)remoteObjectProperties {
    NSMutableSet *properties = [super remoteObjectProperties];
    [properties addObject:@"instanceId"];
    [properties addObject:@"token"];
    [properties addObject:@"launchData"];
    [properties addObject:@"tokenChangedListener"];
    [properties addObject:@"instanceIdChangedListener"];
    [properties addObject:@"messageListener"];
    [properties addObject:@"showBannersInForeground"];
    return properties;
}

+ (NSString *)remoteObjectType {
    return @"com.eclipsesource.firebase.Messaging";
}

+ (void)setLaunchData:(NSDictionary *)launchOptions {
    launchData = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
}

- (NSDictionary *)launchData {
    return launchData;
}

- (UIView *)view {
    return nil;
}

+ (void)setup {
    [ESFirebaseHelper setup];
}

- (NSArray *)getAllPendingMessages {
    __block NSArray *array;
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    [[UNUserNotificationCenter currentNotificationCenter] getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
        if (notifications.count > 0) {
            NSMutableArray *dictionaries = [NSMutableArray arrayWithCapacity:notifications.count];
            for (UNNotification *notification in notifications) {
                [dictionaries addObject:notification.request.content.userInfo];
            }
            array = [[[dictionaries reverseObjectEnumerator] allObjects] copy];
        }
        dispatch_group_leave(group);
    }];
    dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC * 1));
    return array;
}

- (void)clearAllPendingMessages {
    [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
}

- (NSString *)instanceId {
    return [FIRInstanceID instanceID].token;
}

- (NSString *)token {
    return [FIRMessaging messaging].FCMToken;
}

- (void)registerForNotifications {
    UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
    [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:authOptions completionHandler:^(BOOL granted, NSError * _Nullable error) {}];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
}

- (void)resetInstanceId {
    [[FIRInstanceID instanceID] deleteIDWithHandler:^(NSError * _Nullable error) {}];
}

- (void)sendMessage:(NSDictionary *)data {
    if (self.messageListener) {
        [self fireEventNamed:@"message" withAttributes:@{@"data":data}];
    }
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    NSDictionary *userInfo = notification.request.content.userInfo;
    [self sendMessage:userInfo];
    UNNotificationPresentationOptions presentation = self.showBannersInForeground ? UNNotificationPresentationOptionBadge : UNNotificationPresentationOptionNone;
    completionHandler(presentation);
}

#pragma mark - FIRMessagingDelegate

- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    if (self.tokenChangedListener) {
        [self fireEventNamed:@"tokenChanged" withAttributes:@{@"token":fcmToken}];
    }
}

- (void)messaging:(FIRMessaging *)messaging didReceiveMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    [self sendMessage:remoteMessage.appData];
}

- (void)instanceIdRefreshed:(NSNotification *)notification {
    if (self.instanceIdChangedListener) {
        [self fireEventNamed:@"instanceIdChanged" withAttributes:@{@"instanceId":[FIRInstanceID instanceID].token}];
    }
}

@end
