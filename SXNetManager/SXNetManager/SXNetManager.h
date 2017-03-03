//
//  ViewController.m
//  SXNetManager
//
//  Created by dfpo on 16/10/18.
//  Copyright © 2016年 dfpo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

typedef void (^ _Nullable requestSuccessBlock)(id _Nullable responseObject);
typedef void (^ _Nullable requestFailureBlock)(NSString * _Nullable errorString);
/**
 *  网络
 */
@interface SXNetManager : NSObject

+ (_Nonnull instancetype)manager;



/**
 *  发起 post 请求
 *
 *  @param api     api
 *  @param params  参数
 *  @param success
 *  @param failure
 *  @return 本次请求的 hash
 */
- (NSString * _Nonnull)post:(NSString * _Nonnull)api
                            params:(NSDictionary * _Nullable)params
                         HUDString:(NSString *_Nullable) HUDString
                           success:(requestSuccessBlock)success
                           failure:(requestFailureBlock)failure;

/**
 *  发起 get 请求
 *
 *  @param api     api
 *  @param params  参数
 *  @param success
 *  @param failure
 *  @return 本次请求的 hash
 */
- (NSString * _Nonnull)getWithAPI:(NSString * _Nonnull)api
                            params:(NSDictionary * _Nullable)params
                        HUDString:(NSString *_Nullable) HUDString
                           success:(requestSuccessBlock)success
                           failure:(requestFailureBlock)failure;


/**
 *  根据 hash key 来取消对应的请求
 *
 *  @param key hash key
 */
- (void)cancelTaskWithKey:(NSString * _Nonnull)key;
- (void)removeAllCacheWithProgressBlock:(void(^ _Nullable)(int removedCount, int totalCount))progress
                               endBlock:(void(^ _Nullable)(BOOL error))end;
@end
