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
typedef void (^ _Nullable uploadImageSuccessBlock)(NSString  *_Nullable imageIDString);
typedef void (^ _Nullable uploadImageFailureBlock)(NSURLSessionDataTask *_Nullable task, NSString *_Nullable errorString);

/**
 *  网络
 */
@interface SXNetManager : NSObject

/**
 退出登录时调用些方法，清空AuthorizationHeader
 */
- (void)emptyHeader;
#pragma mark - get

/**
 无参数，HUD -> 加载中
 */
- (NSString * _Nonnull)get:(NSString * _Nonnull)api
                   success:(requestSuccessBlock)success
                   failure:(requestFailureBlock)failure;
/**
 带参数，HUD -> 加载中
 */
- (NSString * _Nonnull)get:(NSString * _Nonnull)api
                    params:(NSDictionary * _Nullable)params
                   success:(requestSuccessBlock)success
                   failure:(requestFailureBlock)failure;

/**
 带参数，HUD可自定义
 */
- (NSString * _Nonnull)get:(NSString * _Nonnull)api
                    params:(NSDictionary * _Nullable)params
                 HUDString:(NSString *_Nullable) HUDString
                   success:(requestSuccessBlock)success
                   failure:(requestFailureBlock)failure;
#pragma mark - post
/**
 无参数，HUD -> 加载中
 */
- (NSString * _Nonnull)post:(NSString * _Nonnull)api
                    success:(requestSuccessBlock)success
                    failure:(requestFailureBlock)failure;
/**
 带参数，HUD -> 加载中
 */
- (NSString * _Nonnull)post:(NSString * _Nonnull)api
                     params:(NSDictionary * _Nullable)params
                    success:(requestSuccessBlock)success
                    failure:(requestFailureBlock)failure;

/**
 带参数，HUD可自定义
 */
- (NSString * _Nonnull)post:(NSString * _Nonnull)api
                     params:(NSDictionary * _Nullable)params
                  HUDString:(NSString *_Nullable) HUDString
                    success:(requestSuccessBlock)success
                    failure:(requestFailureBlock)failure;

#pragma mark - cancel task

/**
 取消网络请求
 */
- (void) cancelTaskWithKey:(NSString * _Nonnull)key;

#pragma mark - upload img
/**
 *  上传图片
 */
- (NSURLSessionDataTask * _Nullable)uploadImage:(UIImage *_Nullable)image
                                        success:(uploadImageSuccessBlock)success
                                        failure:(uploadImageFailureBlock)failure;
@end
