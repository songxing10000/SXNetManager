//
//  ViewController.m
//  SXNetManager
//
//  Created by dfpo on 16/10/18.
//  Copyright © 2016年 dfpo. All rights reserved.
//

#import "SXNetManager.h"
#import <AFNetworking.h>
#import "YYCache.h"
#import "YYMemoryCache.h"
#import <MBProgressHUD.h>
#import "AppDelegate.h"

#define BSScreenW [[UIScreen mainScreen] bounds].size.width
#define BSScreenH [[UIScreen mainScreen] bounds].size.height



#ifndef weakify
#if DEBUG
#if __has_feature(objc_arc)
#define weakify(object) autoreleasepool{} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) autoreleasepool{} __block __typeof__(object) block##_##object = object;
#endif
#else
#if __has_feature(objc_arc)
#define weakify(object) try{} @finally{} {} __weak __typeof__(object) weak##_##object = object;
#else
#define weakify(object) try{} @finally{} {} __block __typeof__(object) block##_##object = object;
#endif
#endif
#endif

#ifndef strongify
#if DEBUG
#if __has_feature(objc_arc)
#define strongify(object) autoreleasepool{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) autoreleasepool{} __typeof__(object) object = block##_##object;
#endif
#else
#if __has_feature(objc_arc)
#define strongify(object) try{} @finally{} __typeof__(object) object = weak##_##object;
#else
#define strongify(object) try{} @finally{} __typeof__(object) object = block##_##object;
#endif
#endif
#endif

static NSString * const kBaseURLString = @"http://bosheng.langyadt.com/index.php/api/";
static NSString * const WTNetManagerRequestCache = @"WTNetManagerRequestCache";

typedef NS_ENUM(NSInteger, RequestMethod) {
    RequestMethodGet = 1,///< 发起请求的方式为get
    RequestMethodPost ///< 发起请求的方式为post
};
@interface AppDelegate (add)
+ (instancetype)delegate;
@end
@implementation AppDelegate (add)

+ delegate {
    return(AppDelegate *)[UIApplication sharedApplication].delegate;
}

@end
@interface NSString (add)
/** 去除首尾空白字符和换行字符，以及其他位置的空白字符和换行字符 */
- (NSString *)replaceWhitespaceAndNewLineSymbol;

@end
@implementation NSString (add)
/** 去除首尾空白字符和换行字符，以及其他位置的空白字符和换行字符 */
- (NSString *)replaceWhitespaceAndNewLineSymbol {
    // 1、去除掉内容首尾的空白字符和换行字符
    NSCharacterSet *s = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *str = [self stringByTrimmingCharactersInSet:s];
    // 2、去除掉其它位置的空白字符和换行字符
    str = [str stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    str = [str stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    str = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
    return str;
}
@end




@interface SXNetManager()
{
    AFHTTPSessionManager *_manager;
    NSMutableDictionary  *_taskCache;
    dispatch_queue_t      _cacheQueue;
}
@property (nonatomic) YYCache *yycache;
@end
@implementation SXNetManager
static void *cacheQueueKey;

#pragma mark - life cycle
+ (_Nonnull instancetype)manager {
    static dispatch_once_t onceToken;
    static SXNetManager *instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}
- (instancetype)init
{
    if ( self = [super init] )
    {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 15;

        _taskCache = [NSMutableDictionary dictionaryWithCapacity:10];
        _cacheQueue = dispatch_queue_create("networkmanager_cache_queue", DISPATCH_QUEUE_SERIAL);
        cacheQueueKey = &cacheQueueKey;
        dispatch_queue_set_specific(_cacheQueue, cacheQueueKey, (__bridge void *)self, NULL);
        _manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:kBaseURLString] sessionConfiguration:config];
//        _manager.responseSerializer = [AFJSONResponseSerializer serializer];
        _manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        _manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/html", nil];
        
        [_manager.requestSerializer setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        
        
        // 网络提示
        static UILabel *_warningLabel = nil;
        _warningLabel = [[UILabel alloc]initWithFrame:CGRectMake(-BSScreenW, 64, BSScreenW, 44)];
        _warningLabel.backgroundColor = [UIColor colorWithRed:0.996f green:0.973f blue:0.718f alpha:1.00f];
        _warningLabel.text = @"当前网络不可用,请检查你的网络设置";
        _warningLabel.textAlignment = NSTextAlignmentCenter;
        _warningLabel.font = [UIFont systemFontOfSize:14];
        [[[UIApplication sharedApplication] keyWindow]addSubview:_warningLabel];
        
        @weakify(self);
        [_manager.reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            @strongify(self);
            switch (status) {
                case AFNetworkReachabilityStatusReachableViaWiFi:
                    [self showMsg:@"已连接WiFi" forStatus:YES warningLabel:_warningLabel];
                    break;
                case AFNetworkReachabilityStatusReachableViaWWAN:
                    [self showMsg:@"已连接网络" forStatus:YES warningLabel:_warningLabel];
                    break;
                case AFNetworkReachabilityStatusNotReachable:
                    [self showMsg:@"当前网络不可用,请检查你的网络设置" forStatus:NO warningLabel:_warningLabel];
                    break;
                default:
                    break;
            }
        }];
        
        [_manager.reachabilityManager startMonitoring];
        


    }
    return self;
}


#pragma mark - public
- (void)removeAllCacheWithProgressBlock:(void(^)(int removedCount, int totalCount))progress
                               endBlock:(void(^)(BOOL error))end {
    [[[YYCache alloc] initWithName:WTNetManagerRequestCache] removeAllObjectsWithProgressBlock: progress endBlock:end];
}

//post
- (NSString * _Nonnull)post:(NSString * _Nonnull)api
                            params:(NSDictionary * _Nullable)params
                         HUDString:(NSString *_Nullable) HUDString
                           success:(void (^ _Nullable)(id _Nullable responseObject))success
                           failure:(void (^ _Nullable)(NSString * _Nullable errorString))failure {
    return [self requestWithAPI:api method:RequestMethodPost params:params useCache:NULL HUDString:HUDString
 success:success failure:failure];
}

//get
- (NSString * _Nonnull)getWithAPI:(NSString * _Nonnull)api
                           params:(NSDictionary * _Nullable)params
                        HUDString:(NSString *_Nullable) HUDString
                          success:(void (^ _Nullable)(id _Nullable responseObject))success
                          failure:(void (^ _Nullable)(NSString * _Nullable errorString))failure {
    return [self requestWithAPI:api method:RequestMethodGet params:params  useCache:NULL HUDString:HUDString success:success failure:failure];
}


#pragma mark - category method
- (UIView *)getCurrentView {
    
    UIViewController *vc = [AppDelegate delegate].window.rootViewController;
    if ([vc isKindOfClass:[UITabBarController
                           
                           class]]) {
        UITabBarController *tab = (UITabBarController *)vc;
        UINavigationController *nav = tab.selectedViewController;
        return nav.topViewController.view;
    }
    
    else if ([vc isKindOfClass:[UIViewController class]]) {
        return vc.view;
    } else if ([vc isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)vc;
        
        return nav.topViewController.view;
    } else if([vc isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)vc;
        
        return nav.topViewController.view;
    }
    NSAssert(NO, @"特别情况出现");
    return [UIView new];
}
#pragma mark - getter and setter
- (YYCache *)yycache
{
    if (!_yycache) {
        _yycache = [[YYCache alloc] initWithName:WTNetManagerRequestCache];
        _yycache.memoryCache.shouldRemoveAllObjectsOnMemoryWarning = YES;
        _yycache.memoryCache.shouldRemoveAllObjectsWhenEnteringBackground = YES;
    }
    return _yycache;
}
#pragma mark - private
- (NSString * _Nonnull)requestWithAPI:(NSString * _Nonnull)api
                               method:(RequestMethod)method
                               params:(NSDictionary * _Nullable)params
                             useCache:(void (^ _Nullable)(id _Nullable cacheObject))cacheBlock
                            HUDString:(NSString *_Nullable) HUDString
                              success:(void (^ _Nullable)(id _Nullable responseObject))success
                              failure:(void (^ _Nullable)(NSString * _Nullable errorString))failure {
    // 去掉首尾中间的空格
    api = [api replaceWhitespaceAndNewLineSymbol];
    NSString *hash = [[self class] hashWithAPI:api params:params];
    NSString *cacheKey = hash;
    
    if (params) {
        NSString *paramsString = [self stringWithJSONObject:params];
        cacheKey = [cacheKey stringByAppendingString:paramsString];
    }
    
    
    if (cacheBlock) {
        
        cacheBlock([self.yycache objectForKey:cacheKey]);
    }
    
    MBProgressHUD *hud = nil;
    
    if (HUDString.length != 0)
    {
        hud = [MBProgressHUD showHUDAddedTo:[UIApplication sharedApplication].keyWindow animated:YES];
        hud.label.text = HUDString;
        
    }

    /// 重复请求
    if ([[_taskCache allKeys] containsObject: cacheKey]) {
        return cacheKey;
    }
    
    void (^ respondSuccessBlock)(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) =
    ^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud hideAnimated:YES];
        });
        if ( success )
        {
            success(responseObject);
            
            if (cacheBlock) {
                if ([responseObject isKindOfClass:[NSArray class]] ||
                    [responseObject isKindOfClass:[NSDictionary class]]) {
                    [self.yycache setObject:responseObject forKey:cacheKey];
                }
            }
        
        }
        [self removeWithKey:hash];
    };
    
    void (^ respondErrorBlock)(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) =
    ^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [hud hideAnimated:YES];
        });
        if ( failure ) {
            NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
            NSInteger statuscode = response.statusCode;
            if (statuscode == 401) {
                failure(@"401 未授权） 请求要求身份验证。对于需要登录的网页，服务器可能返回此响应。");
            } else if (statuscode == 404) {
                failure(@"404（未找到） 服务器找不到请求的网页");
            } else if (statuscode == 500) {
                failure(@"500 服务器遇到了一个未曾预料的状况，导致了它无法完成对请求的处理。一般来说，这个问题都会在服务器的程序码出错时出现。");
            } else {
                failure(error.localizedDescription);
            }
        }
        
        [self removeWithKey:hash];
    };
    
    NSURLSessionDataTask *task = nil;
    if (method == RequestMethodGet) {
        
        task = [_manager GET:api parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
            respondSuccessBlock(task, responseObject);
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            
            respondErrorBlock(task, error);
        }];
    } else if (method == RequestMethodPost) {
        
        task = [_manager POST:api parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            
            respondSuccessBlock(task, responseObject);
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            
            respondErrorBlock(task, error);
        }];
    }
    
    
    [self cacheTask:task withKey:hash];
    return hash;
}


- (nullable NSString *)stringWithJSONObject:(nonnull id)JSONObject
{
    if (![NSJSONSerialization isValidJSONObject:JSONObject]){
        NSLog(@"The JSONObject is not JSON Object");
        return nil;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:JSONObject options:NSJSONWritingPrettyPrinted error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
}
+ (NSString *)hashWithAPI:(NSString *)api
                   params:(NSDictionary *)params
{
    NSMutableString *hash = [NSMutableString string];
    [hash appendString:api];
    if ( params )
    {
        [params enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [hash appendFormat:@"%@=%@", key, obj];
        }];
    }
    return hash;
}
- (void)executeSyncOnCacheQueue:(void(^)())block
{
    if ( !block )
    {
        return;
    }
    
    if ( dispatch_get_specific(cacheQueueKey) )
    {
        block();
    }
    else
    {
        dispatch_sync(_cacheQueue, block);
    }
}

- (void)cacheTask:(NSURLSessionDataTask *)task
          withKey:(NSString *)key
{
    if ( !task )
    {
        return;
    }
    
    [self executeSyncOnCacheQueue:^{
        [_taskCache setObject:task forKey:key];
    }];
}

- (void)removeWithKey:(NSString *)key
{
    [self executeSyncOnCacheQueue:^{
        [_taskCache removeObjectForKey:key];
    }];
}

- (void)cancelTaskWithKey:(NSString * _Nonnull)key
{
    [self executeSyncOnCacheQueue:^{
        NSURLSessionDataTask *task = [_taskCache objectForKey:key];
        if ( task )
        {
            [task cancel];
            [self removeWithKey:key];
        }
    }];
}

- (void)showMsg:(NSString*)msg forStatus:(BOOL)status warningLabel:(UILabel*)warningLabel  {
#if 0 // 是否成功登录
    if (![[QHWNotificationSingleton sharedNotification]logged]) {
        return;
    }
#endif
    
    
    if (!status) {
        [[[UIApplication sharedApplication] keyWindow]addSubview:warningLabel];
        warningLabel.text = msg;
        __block CGRect rect = warningLabel.frame;
        [UIView animateWithDuration:0.3 animations:^{
            rect.origin.x = 0;
            warningLabel.frame = rect;
        }];
    }
    else {
        if (warningLabel && warningLabel.frame.origin.x == 0) {
            
            [UIView transitionWithView:warningLabel duration:0.33 options:UIViewAnimationOptionTransitionFlipFromTop animations:^{
                warningLabel.text = msg;
            } completion:^(BOOL finished) {
                __block CGRect rect = warningLabel.frame;
                [UIView animateWithDuration:0.6 animations:^{
                    rect.origin.x = BSScreenW;
                    warningLabel.frame = rect;
                } completion:^(BOOL finished) {
                    rect.origin.x = -BSScreenW;
                    warningLabel.frame = rect;
                    [warningLabel removeFromSuperview];
                }];
            }];
            
            
        }
    }
}
- (NSString *)stringWithFormat:(NSString *)aFormat fromDate:(NSDate *)aDate {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:aFormat];
    [formatter setLocale:[NSLocale currentLocale]];
    return [formatter stringFromDate:aDate];
}

- (NSString *)mimeTypeForData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    
    switch (c) {
        case 0xFF:
            return @"image/jpeg";
            break;
        case 0x89:
            return @"image/png";
            break;
        case 0x47:
            return @"image/gif";
            break;
        case 0x49:
        case 0x4D:
            return @"image/tiff";
            break;
        case 0x25:
            return @"application/pdf";
            break;
        case 0xD0:
            return @"application/vnd";
            break;
        case 0x46:
            return @"text/plain";
            break;
        default:
            return @"application/octet-stream";
    }
    return nil;
}
        @end
