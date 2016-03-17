//
//  ZXDDownLoadManger.m
//  ZXDDownLoadManager
//
//  Created by 张雪东 on 16/1/17.
//  Copyright © 2016年 ZXD. All rights reserved.
//

#import "ZXDDownloadManger.h"
#import "NSString+Hash.h"

// 缓存主目录
#define ZXDCachesDirectory [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"ZXDCache"]

// 保存文件名
#define ZXDFileName(url) url.md5String

// 文件的存放路径（caches）
#define ZXDFileFullpath(url) [ZXDCachesDirectory stringByAppendingPathComponent:ZXDFileName(url)]

// 文件的已下载长度
#define ZXDDownloadLength(url) [[[NSFileManager defaultManager] attributesOfItemAtPath:ZXDFileFullpath(url) error:nil][NSFileSize] integerValue]

// 存储文件总长度的文件路径（caches）
#define ZXDTotalLengthFullpath [ZXDCachesDirectory stringByAppendingPathComponent:@"totalLength.plist"]

@interface ZXDDownloadManger ()<NSCopying,NSURLSessionDelegate>

// 保存所有任务(注：用下载地址md5后作为key)
@property (nonatomic, strong) NSMutableDictionary *tasks;
// 保存所有下载相关信息
@property (nonatomic, strong) NSMutableDictionary *sessionModels;

@end

@implementation ZXDDownloadManger

static ZXDDownloadManger *manager;
+(instancetype)shareInstance{

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[ZXDDownloadManger alloc] init];
    });
    return manager;
}

+(instancetype)allocWithZone:(struct _NSZone *)zone{

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [super allocWithZone:zone];
    });
    return manager;
}

-(id)copyWithZone:(NSZone *)zone{

    return manager;
}

- (NSMutableDictionary *)tasks
{
    if (!_tasks) {
        _tasks = [NSMutableDictionary dictionary];
    }
    return _tasks;
}

- (NSMutableDictionary *)sessionModels
{
    if (!_sessionModels) {
        _sessionModels = [NSMutableDictionary dictionary];
    }
    return _sessionModels;
}

- (void)createCacheDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:ZXDCachesDirectory]) {
        [fileManager createDirectoryAtPath:ZXDCachesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

- (void)download:(NSString *)url progress:(void (^)(NSInteger, NSInteger, CGFloat))progressBlock state:(void (^)(DownloadState))stateBlock
{
    if (!url) return;
    if ([self isCompletion:url]) {
        stateBlock(DownloadStateCompleted);
        NSLog(@"----该资源已下载完成");
        return;
    }
    
    // 暂停
    if ([self.tasks valueForKey:ZXDFileName(url)]) {
        [self handle:url];
        
        return;
    }
    
    // 创建缓存目录文件
    [self createCacheDirectory];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[[NSOperationQueue alloc] init]];
    
    // 创建流
    NSOutputStream *stream = [NSOutputStream outputStreamToFileAtPath:ZXDFileFullpath(url) append:YES];
    
    // 创建请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    // 设置请求头
    NSString *range = [NSString stringWithFormat:@"bytes=%zd-", ZXDDownloadLength(url)];
    [request setValue:range forHTTPHeaderField:@"Range"];
    
    // 创建一个Data任务
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
    NSUInteger taskIdentifier = arc4random() % ((arc4random() % 10000 + arc4random() % 10000));
    [task setValue:@(taskIdentifier) forKeyPath:@"taskIdentifier"];
    
    // 保存任务
    [self.tasks setValue:task forKey:ZXDFileName(url)];
    
    ZXDSessionModel *sessionModel = [[ZXDSessionModel alloc] init];
    sessionModel.url = url;
    sessionModel.progressBlock = progressBlock;
    sessionModel.stateBlock = stateBlock;
    sessionModel.stream = stream;
    [self.sessionModels setValue:sessionModel forKey:@(task.taskIdentifier).stringValue];
    
    [self start:url];
}


- (void)handle:(NSString *)url
{
    NSURLSessionDataTask *task = [self getTask:url];
    if (task.state == NSURLSessionTaskStateRunning) {
        [self pause:url];
    } else {
        [self start:url];
    }
}

- (void)start:(NSString *)url
{
    NSURLSessionDataTask *task = [self getTask:url];
    [task resume];
    
    [self getSessionModel:task.taskIdentifier].stateBlock(DownloadStateStart);
}

- (void)pause:(NSString *)url
{
    NSURLSessionDataTask *task = [self getTask:url];
    [task suspend];
    
    [self getSessionModel:task.taskIdentifier].stateBlock(DownloadStateSuspended);
}

- (NSURLSessionDataTask *)getTask:(NSString *)url
{
    return (NSURLSessionDataTask *)[self.tasks valueForKey:ZXDFileName(url)];
}

- (ZXDSessionModel *)getSessionModel:(NSUInteger)taskIdentifier
{
    return (ZXDSessionModel *)[self.sessionModels valueForKey:@(taskIdentifier).stringValue];
}

- (BOOL)isCompletion:(NSString *)url
{
    if ([self fileTotalLength:url] && ZXDDownloadLength(url) == [self fileTotalLength:url]) {
        return YES;
    }
    return NO;
}

- (CGFloat)progress:(NSString *)url
{
    return [self fileTotalLength:url] == 0 ? 0.0 : 1.0 * ZXDDownloadLength(url) /  [self fileTotalLength:url];
}

- (NSInteger)fileTotalLength:(NSString *)url
{
    return [[NSDictionary dictionaryWithContentsOfFile:ZXDTotalLengthFullpath][ZXDFileName(url)] integerValue];
}

#pragma mark - 删除
- (void)deleteFile:(NSString *)url
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:ZXDFileFullpath(url)]) {
        
        // 删除沙盒中的资源
        [fileManager removeItemAtPath:ZXDFileFullpath(url) error:nil];
        // 删除任务
        [self.tasks removeObjectForKey:ZXDFileName(url)];
        [self.sessionModels removeObjectForKey:@([self getTask:url].taskIdentifier).stringValue];
        // 删除资源总长度
        if ([fileManager fileExistsAtPath:ZXDTotalLengthFullpath]) {
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:ZXDTotalLengthFullpath];
            [dict removeObjectForKey:ZXDFileName(url)];
            [dict writeToFile:ZXDTotalLengthFullpath atomically:YES];
            
        }
    }
}

- (void)deleteAllFile
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:ZXDCachesDirectory]) {
        // 删除沙盒中所有资源
        [fileManager removeItemAtPath:ZXDCachesDirectory error:nil];
        // 删除任务
        [[self.tasks allValues] makeObjectsPerformSelector:@selector(cancel)];
        [self.tasks removeAllObjects];
        
        for (ZXDSessionModel *sessionModel in [self.sessionModels allValues]) {
            [sessionModel.stream close];
        }
        [self.sessionModels removeAllObjects];
        
        // 删除资源总长度
        if ([fileManager fileExistsAtPath:ZXDTotalLengthFullpath]) {
            [fileManager removeItemAtPath:ZXDTotalLengthFullpath error:nil];
        }
    }
}

#pragma mark - 代理
#pragma mark NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    
    ZXDSessionModel *sessionModel = [self getSessionModel:dataTask.taskIdentifier];
    
    // 打开流
    [sessionModel.stream open];
    
    // 获得服务器这次请求 返回数据的总长度
    NSInteger totalLength = [response.allHeaderFields[@"Content-Length"] integerValue] + ZXDDownloadLength(sessionModel.url);
    sessionModel.totalLength = totalLength;
    
    // 存储总长度
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:ZXDTotalLengthFullpath];
    if (dict == nil) dict = [NSMutableDictionary dictionary];
    dict[ZXDFileName(sessionModel.url)] = @(totalLength);
    [dict writeToFile:ZXDTotalLengthFullpath atomically:YES];
    
    // 接收这个请求，允许接收服务器的数据
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    ZXDSessionModel *sessionModel = [self getSessionModel:dataTask.taskIdentifier];
    
    // 写入数据
    [sessionModel.stream write:data.bytes maxLength:data.length];
    
    // 下载进度
    NSUInteger receivedSize = ZXDDownloadLength(sessionModel.url);
    NSUInteger expectedSize = sessionModel.totalLength;
    CGFloat progress = 1.0 * receivedSize / expectedSize;
    
    sessionModel.progressBlock(receivedSize, expectedSize, progress);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    ZXDSessionModel *sessionModel = [self getSessionModel:task.taskIdentifier];
    if (!sessionModel) return;
    
    if ([self isCompletion:sessionModel.url]) {
        // 下载完成
        sessionModel.stateBlock(DownloadStateCompleted);
    } else if (error){
        // 下载失败
        sessionModel.stateBlock(DownloadStateFailed);
    }
    
    // 关闭流
    [sessionModel.stream close];
    sessionModel.stream = nil;
    
    // 清除任务
    [self.tasks removeObjectForKey:ZXDFileName(sessionModel.url)];
    [self.sessionModels removeObjectForKey:@(task.taskIdentifier).stringValue];
}

@end
