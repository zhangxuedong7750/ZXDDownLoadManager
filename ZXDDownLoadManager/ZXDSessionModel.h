//
//  ZXDSessionModel.h
//  ZXDDownLoadManager
//
//  Created by 张雪东 on 16/1/17.
//  Copyright © 2016年 ZXD. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, DownloadState) {
    DownloadStateStart,
    DownloadStateSuspended,
    DownloadStateCompleted,
    DownloadStateFailed,
};

@interface ZXDSessionModel : NSObject

@property (nonatomic, strong) NSOutputStream *stream;

@property (nonatomic, copy) NSString *url;

@property (nonatomic, assign) NSInteger totalLength;

@property (nonatomic, copy) void(^progressBlock)(NSInteger receivedSize, NSInteger expectedSize, CGFloat progress);

@property (nonatomic, copy) void(^stateBlock)(DownloadState state);

@end
