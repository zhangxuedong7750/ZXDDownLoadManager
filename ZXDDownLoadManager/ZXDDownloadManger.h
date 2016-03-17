//
//  ZXDDownLoadManger.h
//  ZXDDownLoadManager
//
//  Created by 张雪东 on 16/1/17.
//  Copyright © 2016年 ZXD. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ZXDSessionModel.h"

@interface ZXDDownloadManger : NSObject

+(instancetype)shareInstance;

- (void)download:(NSString *)url progress:(void(^)(NSInteger receivedSize, NSInteger expectedSize, CGFloat progress))progressBlock state:(void(^)(DownloadState state))stateBlock;

- (CGFloat)progress:(NSString *)url;

- (NSInteger)fileTotalLength:(NSString *)url;

- (BOOL)isCompletion:(NSString *)url;

- (void)deleteFile:(NSString *)url;

- (void)deleteAllFile;

@end
