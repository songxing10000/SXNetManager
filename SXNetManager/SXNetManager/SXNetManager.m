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
- (instancetype)init {
    
    if ( self = [super init] ) {
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 8;
        
        _taskCache = [NSMutableDictionary dictionaryWithCapacity:10];
        _cacheQueue = dispatch_queue_create("networkmanager_cache_queue", DISPATCH_QUEUE_SERIAL);
        cacheQueueKey = &cacheQueueKey;
        dispatch_queue_set_specific(_cacheQueue, cacheQueueKey, (__bridge void *)self, NULL);
        
        _manager = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:@"baseURLString"] sessionConfiguration:config];
        _manager.requestSerializer  = [AFJSONRequestSerializer serializer];
        _manager.responseSerializer = [AFJSONResponseSerializer serializer];
        
        _manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", nil];
        [_manager.requestSerializer setValue:@"application/vnd.chekuaikuai.v1+json" forHTTPHeaderField:@"Accept"];
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
                    // 上传图片可提醒用户
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

- (void)emptyHeader {
    [_manager.requestSerializer clearAuthorizationHeader];
}


#pragma mark get
- (NSString * _Nonnull)get:(NSString * _Nonnull)api
                   success:(requestSuccessBlock)success
                   failure:(requestFailureBlock)failure {
    return [self get:api params:nil success:success failure:failure];
}

- (NSString * _Nonnull)get:(NSString * _Nonnull)api
                    params:(NSDictionary * _Nullable)params
                   success:(requestSuccessBlock)success
                   failure:(requestFailureBlock)failure {
    return [self get:api params:params HUDString:@"加载中..." success:success failure:failure];
}

- (NSString * _Nonnull)get:(NSString * _Nonnull)api
                    params:(NSDictionary * _Nullable)params
                 HUDString:(NSString *_Nullable) HUDString
                   success:(requestSuccessBlock)success
                   failure:(requestFailureBlock)failure {
    return [self requestWithAPI:api method:RequestMethodGet params:params useCache:NULL HUDString:HUDString success:success failure:failure];
}


#pragma mark post
- (NSString * _Nonnull)post:(NSString * _Nonnull)api
                    success:(requestSuccessBlock)success
                    failure:(requestFailureBlock)failure {
    return [self post:api params:nil success:success failure:failure];
}

- (NSString * _Nonnull)post:(NSString * _Nonnull)api
                     params:(NSDictionary * _Nullable)params
                    success:(requestSuccessBlock)success
                    failure:(requestFailureBlock)failure {
    return [self post:api params:params HUDString:@"加载中..." success:success failure:failure];
}

- (NSString * _Nonnull)post:(NSString * _Nonnull)api
                     params:(NSDictionary * _Nullable)params
                  HUDString:(NSString *_Nullable) HUDString
                    success:(requestSuccessBlock)success
                    failure:(requestFailureBlock)failure {
    return [self requestWithAPI:api method:RequestMethodPost params:params useCache:NULL HUDString:HUDString success:success failure:failure];
}

#pragma mark upload img
/// 上传图片
- (NSURLSessionDataTask * _Nullable)uploadImage:(UIImage *_Nullable)image
                                        success:(void (^_Nullable)(NSString  *_Nullable imageIDString))success
                                        failure:(void (^_Nullable)(NSURLSessionDataTask *_Nullable task, NSString *_Nullable errorString))failure {
    
    
    
    AFHTTPSessionManager    *singleManager = [[AFHTTPSessionManager alloc]initWithBaseURL:[NSURL  URLWithString:@"xx"]];
    singleManager.operationQueue.maxConcurrentOperationCount = 4 ;
    
    singleManager.requestSerializer = [AFHTTPRequestSerializer serializer];
    singleManager.responseSerializer = [AFJSONResponseSerializer serializer];
    //
    singleManager.responseSerializer.acceptableContentTypes =
    [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript",@"text/html", nil];
    singleManager.requestSerializer.timeoutInterval = 15;
    
    
    NSURLSessionDataTask *task = [singleManager POST:@"xxx" parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        @autoreleasepool {
            
            if (image) {
                
                // 压缩图片
                NSData* compressionImageData = nil;
                
                // 压缩到服务器要求 的2 M
                NSData *data = compressionImageData;
                NSString *currentDateString = @"yyyy/MM/dd日/HH/mm/ss";
                NSString *dateString = [NSString stringWithFormat:@"%@/%@.png", currentDateString, @"songxing"];
                NSString *fileName = dateString;
                NSAssert([fileName hasSuffix:@".png"], @"没有以.png命名");
                
                [formData appendPartWithFileData:data
                                            name:@"file"// 服务器要的file
                                        fileName:fileName
                                        mimeType:[self mimeTypeForData:data]];
            }
        }
        
    } progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
    
        if ([responseObject[@"errcode"] isEqual:@0]) {
            
            // data	int	图片id (用于企业信息店铺信息中图片上传中的图片字段)
            if (success) { success(responseObject[@"data"]);}
        } else {
            if (failure) { failure(task,responseObject[@"errstr"]);}
            
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        failure(task, error.localizedDescription);
    }];
    
    return task;
}

#pragma mark - category method
- (UIView *)getCurrentView {
    
    return [self topViewControllerWithRootViewController:[UIApplication sharedApplication].keyWindow.rootViewController].view;
}

- (UIViewController*)topViewControllerWithRootViewController:(UIViewController*)rootViewController {
    
    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        
        UITabBarController* tabBarController = (UITabBarController*)rootViewController;
        return [self topViewControllerWithRootViewController:tabBarController.selectedViewController];
    } else if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        
        UINavigationController* navigationController = (UINavigationController*)rootViewController;
        return [self topViewControllerWithRootViewController:navigationController.visibleViewController];
    } else if (rootViewController.presentedViewController) {
        
        UIViewController* presentedViewController = rootViewController.presentedViewController;
        return [self topViewControllerWithRootViewController:presentedViewController];
    }
    
    return rootViewController;
}

#pragma mark - private
- (NSString * _Nonnull)requestWithAPI:(NSString * _Nonnull)api
                               method:(RequestMethod)method
                               params:(NSDictionary * _Nullable)params
                             useCache:(void (^ _Nullable)(id _Nullable cacheObject))cacheBlock
                            HUDString:(NSString *_Nullable) HUDString
                              success:(requestSuccessBlock)success
                              failure:(requestFailureBlock)failure {
    
    api = [api stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    
    NSString *hash = [[self class] hashWithAPI:api params:params];
    NSString *cacheKey = hash;
    
    NSString *paramsString = [self stringWithJSONObject:params];
    if (paramsString && paramsString.length){
        
        cacheKey = [cacheKey stringByAppendingString:paramsString];
    }
    
    
#pragma mark 限制重复请求
    if ([[_taskCache allKeys] containsObject: cacheKey]) {
        return cacheKey;
    }
    
#pragma mark 成功的块
    void (^ respondSuccessBlock)(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) =
    ^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        [self removeWithKey:hash];
        
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            // 返回的数据没有按正常数据返回，直接返回此数据
            success(responseObject);
            
        } else {
            
            NSDictionary *responseDic = (NSDictionary *)responseObject;
            NSInteger status = [responseDic[@"status_code"] integerValue];
            id data = responseDic[@"data"];
            NSString *errorMsg = responseDic[@"message"];
            
            if (status != 0 ) {
                
                if (failure) {
                    failure(errorMsg);
                }
            } else {
                
                if (success) {
                    
                    if (data) {
                        success(data);
                        
                    } else {
                        success(responseObject);
                    }
                }
            }
        }
        
    };
#pragma mark 失败的块
    void (^ respondErrorBlock)(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) =
    ^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        [self removeWithKey:hash];
        
        
        //        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        //        NSInteger statuscode = response.statusCode;
        
        if ( failure ) {
            
            NSData *errorData =
            error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
            
            if (errorData == nil) {
                if (error.localizedDescription) {
                    
                    failure(error.localizedDescription);
                } else {
                    
                    failure(@"有可能是网络断开了");
                }
                return ;
            }
            
            NSDictionary *errorDict =
            [NSJSONSerialization JSONObjectWithData: errorData options:kNilOptions error:nil];
            
            if (errorDict == nil) {
                NSString *errorStr =
                [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
                if (errorStr.length) {
                    failure(errorStr);
                } else {
                    failure(@"请求失败，服务器没有返回错误信息的字典");
                }
            }
            
            NSString *msg = errorDict[@"message"];
            id codeIDObj = errorDict[@"code"];
            
            if (msg && msg.length) {
                
                
                // 处理特别msg
                if ([msg isEqualToString:@"Token has expired"]) {
                    
                    failure(msg);
                    
                } else {
                    
                    // 非特别msg直接返回给上层调用者
                    failure(msg);
                }
                
                // 没有msg就看code
            } else {
                failure(@"服务器没有返回错误描述相关的字符串或是错误码");
            }
        }
        
        
    };
    
    
    
#pragma mark 分get post delete 发起请求
    // 准备开启task
    NSURLSessionDataTask *task = nil;
    if (method == RequestMethodGet) {
        NSString* etag = (NSString *)[self.yycache objectForKey:cacheKey];
        if (etag != nil){

            [_manager.requestSerializer setValue:etag forHTTPHeaderField:@"If-None-Match"];
        }
        
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

#pragma mark - 从 JSON 到 NSString
- (nullable NSString *)stringWithJSONObject:(nonnull id)JSONObject {
    
    if (![NSJSONSerialization isValidJSONObject:JSONObject]){
        NSLog(@"The JSONObject is not JSON Object");
        return nil;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:JSONObject options:NSJSONWritingPrettyPrinted error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
}
#pragma mark hask api and parsms
+ (NSString *)hashWithAPI:(NSString *)api params:(NSDictionary *)params {
    
    NSMutableString *hash = [NSMutableString string];
    [hash appendString:api];
    if (params) {
        
        [params enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [hash appendFormat:@"%@=%@", key, obj];
        }];
    }
    return hash;
}


- (void)executeSyncOnCacheQueue:(void(^)())block {
    
    if ( !block ) {
        
        return;
    }
    if (dispatch_get_specific(cacheQueueKey)) {
        
        block();
    } else {
        dispatch_sync(_cacheQueue, block);
    }
}
#pragma mark 缓存一个任务用一个key
- (void)cacheTask:(NSURLSessionDataTask *)task withKey:(NSString *)key{
    
    if ( !task ) {
        
        return;
    }
    
    [self executeSyncOnCacheQueue:^{
        _taskCache[key] = task;
    }];
}
#pragma mark 从任务缓存字典里移除一个任务
- (void)removeWithKey:(NSString *)key {
    
    [self executeSyncOnCacheQueue:^{
        
        [_taskCache removeObjectForKey:key];
    }];
}
#pragma mark 取消一个任务
- (void)cancelTaskWithKey:(NSString * _Nonnull)key {
    
    [self executeSyncOnCacheQueue:^{
        
        NSURLSessionDataTask *task = _taskCache[key];
        if ( task ) {
            
            [task cancel];
            [self removeWithKey:key];
        }
    }];
}
#pragma mark - 没网络情况下的控件展示
- (void)showMsg:(NSString*)msg forStatus:(BOOL)status warningLabel:(UILabel*)warningLabel  {
    
    if (!status) {
        [[[UIApplication sharedApplication] keyWindow]addSubview:warningLabel];
        warningLabel.text = msg;
        __block CGRect rect = warningLabel.frame;
        [UIView animateWithDuration:0.3 animations:^{
            rect.origin.x = 0;
            warningLabel.frame = rect;
        }];
        return;
    }
    
    BOOL needHideWarningLabel = (warningLabel && warningLabel.frame.origin.x == 0);
    if (!needHideWarningLabel) {
        return;
    }
    
    [UIView transitionWithView:warningLabel duration:0.33 options:UIViewAnimationOptionTransitionFlipFromTop animations:^{
        
        warningLabel.text = msg;
    } completion:^(BOOL finished1) {
        
        __block CGRect rect = warningLabel.frame;
        
        [UIView animateWithDuration:0.6 animations:^{
            
            rect.origin.x = [[UIScreen mainScreen] bounds].size.width;
            warningLabel.frame = rect;
        } completion:^(BOOL finished2) {
            
            rect.origin.x = -[[UIScreen mainScreen] bounds].size.width;
            warningLabel.frame = rect;
            [warningLabel removeFromSuperview];
        }];
    }];
    
    
    
    
}

#pragma mark - 判断二进制的文件格式
- (NSString *)mimeTypeForData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    
    switch (c) {
        case 0xFF:
            return @"image/jpeg";
        case 0x89:
            return @"image/png";
        case 0x47:
            return @"image/gif";
        case 0x49:
        case 0x4D:
            return @"image/tiff";
        case 0x25:
            return @"application/pdf";
        case 0xD0:
            return @"application/vnd";
        case 0x46:
            return @"text/plain";
        default:
            return @"application/octet-stream";
    }
    return nil;
}

@end
