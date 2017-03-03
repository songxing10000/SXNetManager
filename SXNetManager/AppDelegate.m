//
//  AppDelegate.m
//  SXNetManager
//
//  Created by dfpo on 16/10/18.
//  Copyright © 2016年 dfpo. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [self initCache];
    
    return YES;
}
#pragma mark - other

/**
 设置URL缓存
 */
- (void)initCache {
    
    NSURLCache *cache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024
                                                      diskCapacity:20 * 1024 * 1024
                                                          diskPath:@"NSURLCache"];
    [NSURLCache setSharedURLCache:cache];
}
@end
