//
//  BGMPlayer.m
//  MycoreText
//
//  Created by Trillion on 2017/4/17.
//  Copyright © 2017年 Trillion. All rights reserved.
//

#import "BGMPlayer.h"

#define Player [BGMPlayer getPlayer]

typedef void(^callBack)(void);
typedef void(^progressBack)(float time , float total);
typedef void(^pauseBack)(BOOL pauseFlag);

@interface BGMPlayer()

@property (nonatomic , strong) AVPlayer * player;

@property (nonatomic , strong) AVPlayerItem * item;

//@property (nonatomic , strong) NSDictionary * musicInfo;

@property (copy,nonatomic) callBack statusCallBack;
@property (copy,nonatomic) callBack LoadingCallBack;
@property (copy,nonatomic) callBack BufferEmptyCallBack;
@property (copy,nonatomic) progressBack duringTimeCallBack;
@property (copy,nonatomic) callBack FinishedCallBack;
@property (copy,nonatomic) pauseBack pauseCallBack;

@end

@implementation BGMPlayer {
    //注册播放状态通知 用于进行释放用
    id _observe;
}

+ (BGMPlayer *) getPlayer {
    
    static BGMPlayer * BGMplayer = nil;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        BGMplayer = [BGMPlayer new];

    });
    
    return BGMplayer;
    
}

//缓冲状态监听
void itemStatusCallBack(void (^block) (void)) {
    Player.statusCallBack = block;
}

//缓冲进度监听
void itemLoadingCallBack(void (^block) (void)) {
    Player.LoadingCallBack = block;
}

//这个empty很神奇 就算是空 也没见响应过 都是状态失败而已
void itemBufferEmptyCallBack(void (^block) (void)) {
    Player.BufferEmptyCallBack = block;
}

//播放进度监听
void duringTimeCallBack(void (^block) (float time , float total)) {
    Player.duringTimeCallBack = block;
}

//播放完成 回调
void playFinishedCallBack(void (^block) (void)) {
    Player.FinishedCallBack = block;
}

void pauseCallBack(void (^block) (BOOL pauseFlag)) {
    Player.pauseCallBack = block;
}

void playOrPause (BOOL pause) {
    if (isPlaying() && pause) {
        [Player.player pause];
    } else {
        [Player.player play];
    }
}

void play (NSURL * url) {
    
    //再次play有很大问题 另外 mvc 要用起来
    if (Player.player) {
        stop();
    }
    
    Player.item = [AVPlayerItem playerItemWithURL:url];

    Player.player = [AVPlayer playerWithPlayerItem:Player.item];
    
    Player.player.volume = 1.;
    
    
    [Player.item addObserver:Player
                  forKeyPath:@"status"
                     options:NSKeyValueObservingOptionNew
                     context: nil];

    // 观察缓冲进度
    [Player.item addObserver:Player
                  forKeyPath:@"loadedTimeRanges"
                     options:NSKeyValueObservingOptionNew
                     context:nil];

    [Player.item addObserver:Player
                  forKeyPath:@"playbackBufferEmpty"
                     options:NSKeyValueObservingOptionNew
                     context:nil];

    [[NSNotificationCenter defaultCenter] addObserver:Player
                                             selector:@selector(playbackFinished:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:Player.item];
    
    /**
     *  一个播放进度的监听 需要研究
     *  相关文章:
     *  http://blog.csdn.net/qq_30513483/article/details/50968817
     */

    Player -> _observe = [Player.player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0)
                                                                     queue:dispatch_get_main_queue()
                                                                usingBlock:^(CMTime time) {
                                                                    
                                                                    float current = CMTimeGetSeconds(time);
                                                                    
                                                                    if (current) {

                                                                        float total = CMTimeGetSeconds(Player.item.duration);
                                                                        
                                                                        //NSLog(@"播放进度 %.2f",current / total);
                                                                        //NSLog(@"播放进度 time:%.2f total:%.2f",current , total);
                                                                        //NSLog(@"PeriodicTime:%@", [NSThread currentThread]);
                                                                        
                                                                        //播放时监听事件
                                                                        if (Player.duringTimeCallBack) {
                                                                            Player.duringTimeCallBack(current , total);
                                                                        }
                                                                    }
                                                                }];
    
    [Player.player play];
    
    //咱们先别这么生猛 伴随播放获取后台控制吧 淡定……
    
    //想了个阴招 就是当这个player被唯一初始化时 开始设置后台播放权限 最大限度的防止流氓获取后台播放权限
    AVAudioSession *session = [AVAudioSession sharedInstance];
    //后台播放
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
    
    //注册音频打断通知
    [[NSNotificationCenter defaultCenter] addObserver:Player
                                             selector:@selector(audioSessionInterrupted:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];
}

void playRate (float progress) {
    NSLog(@"完事了!");
    if (isPlaying() && Player.item) {
        
        printf("总长度：%.2f \n",CMTimeGetSeconds(Player.item.duration));

        //设置播放长度
        float time = CMTimeGetSeconds(Player.item.duration) * progress;
        CMTime currentTime = CMTimeMake(time, 1);

        [Player.item seekToTime:currentTime completionHandler:nil];
    }
}

void playLoop (void) {
    if (Player.item) {
        //Player.item.reversePlaybackEndTime = 0;
        [Player.player seekToTime:kCMTimeZero];
        [Player.player play];
    }
}

- (void)playbackFinished:(NSNotification *)notice {
//    NSLog(@"播放完成");

    //播放完成即移除通知
//    [[NSNotificationCenter defaultCenter] removeObserver:self
//                                                    name:AVPlayerItemDidPlayToEndTimeNotification
//                                                  object:Player.item];

//    [self.item removeObserver:self
//                   forKeyPath:@"status"];
    
//    [self.item removeObserver:self
//                   forKeyPath:@"loadedTimeRanges"];
    
//    [self.item removeObserver:self
//                   forKeyPath:@"playbackBufferEmpty"];
    
//    [self.player removeTimeObserver:];

    if (Player.FinishedCallBack) {
        Player.FinishedCallBack();
    }
}


BOOL isPlaying () {
    
    BOOL playing = NO;

    if (Player.player.rate > 0 && Player.player.error == nil) {
        //playing
        playing = YES;
    }
    
    return playing;
}

void stop () {
    if (Player.player) {
        [Player.player pause];
        //用共享了 dealloc 再制空吧
        //Player.player = nil;
    }
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void*)context
{
    
    if([keyPath isEqualToString:@"status"]) {
        
        //取出status的新值
        
        AVPlayerItemStatus status = [change[NSKeyValueChangeNewKey] intValue];
        
        switch(status) {
                
            case AVPlayerItemStatusFailed:{
                
                NSLog(@"item 有误");
                
                if (Player.statusCallBack)
                    Player.statusCallBack();
            }
                break;
                
            case AVPlayerItemStatusReadyToPlay: {
                
                NSLog(@"准好播放了");
                
                NSLog(@"正在播放...，视频总长度:%.2f",CMTimeGetSeconds(self.item.duration));

//                if (Player.LoadingCallBack) {
//                    Player.LoadingCallBack();
            }
                break;
                
            case AVPlayerItemStatusUnknown:{
                
                NSLog(@"视频资源出现未知错误");

//                if (Player.LoadingCallBack)
//                    Player.LoadingCallBack();
            }
                break;
                
            default:
                
                break;     
                
        }   
        
    }
    
    if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        
        NSArray *array = self.item.loadedTimeRanges;
        CMTimeRange timeRange = [array.firstObject CMTimeRangeValue];//本次缓冲时间范围
        float startSeconds = CMTimeGetSeconds(timeRange.start);
        float durationSeconds = CMTimeGetSeconds(timeRange.duration);
        NSTimeInterval totalBuffer = startSeconds + durationSeconds;//缓冲总长度
        NSLog(@"共缓冲：%.2f",totalBuffer);

        if (Player.LoadingCallBack) {
            Player.LoadingCallBack();
        }
    }
    
    //这个值是干啥的啊
    if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        NSLog(@"playbackBufferEmpty");
        if (Player.BufferEmptyCallBack) {
            Player.BufferEmptyCallBack();
        }
    }
}

- (void)audioSessionInterrupted:(NSNotification *)notification {
    
    NSLog(@"%@",notification.userInfo);
    
    AVAudioSessionInterruptionType type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] intValue];
    
    //收到系统通知 被打断时暂停 被打断结束后 重新play
    if (type == AVAudioSessionInterruptionTypeBegan) {
        //[self pause];
        if (self.pauseCallBack) {
            self.pauseCallBack(YES);
        }
    } else {
        if (self.pauseCallBack) {
            self.pauseCallBack(NO);
        }
    }
    
}

-(BOOL)canBecomeFirstResponder{
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *) receivedEvent {
    
    //&& [musicListVC shareMusicListVC]
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        
        switch (receivedEvent.subtype) { // 得到事件类型
                
                //狗屁iOS6啊 这个是耳机play键响应事件 还有相关事件 下面帖子记录一下吧
                //https://www.jianshu.com/p/87f3f2024038
            case UIEventSubtypeRemoteControlTogglePlayPause: // 暂停 ios6
                NSLog(@"播放");
                if (self.pauseCallBack) {
                    self.pauseCallBack(YES);
                }
                break;
                
            case UIEventSubtypeRemoteControlPreviousTrack:  // 上一首
                NSLog(@"上一曲");
                break;
                
            case UIEventSubtypeRemoteControlNextTrack: // 下一首
                NSLog(@"下一曲");
                break;
                
            case UIEventSubtypeRemoteControlPlay: //播放
                if (self.pauseCallBack) {
                    self.pauseCallBack(YES);
                }
                break;
                
            case UIEventSubtypeRemoteControlPause: // 暂停 ios7
                if (self.pauseCallBack) {
                    self.pauseCallBack(YES);
                }
                break;
                
            default:
                
                break;
                
        }
    }
}

void configNowPlayingInfoCenter() {

    @autoreleasepool {

        //设置锁屏状态下屏幕显示播放音乐信息
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

        //歌曲名称
        [dict setObject:@"Trillion 的私藏" forKey:MPMediaItemPropertyTitle];

        //演唱者
        [dict setObject:@"Trillion" forKey:MPMediaItemPropertyArtist];

        //专辑名
        [dict setObject:@"Trillion 的专辑" forKey:MPMediaItemPropertyAlbumTitle];

        //专辑缩略图
        UIImage *image = [UIImage imageNamed:@"logo"];

        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:image.size
                                                                      requestHandler:^UIImage * _Nonnull(CGSize size) {
                                                                          return image;
                                                                      }];

        [dict setObject:artwork forKey:MPMediaItemPropertyArtwork];
                
        NSLog(@"currentTime:%f", CMTimeGetSeconds(Player.item.currentTime));
        
        //音乐当前已经播放时间
        [dict setObject:[NSNumber numberWithDouble:CMTimeGetSeconds(Player.item.currentTime)]
                 forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];

        //进度光标的速度 （这个随 自己的播放速率调整，我默认是原速播放）
        [dict setObject:[NSNumber numberWithFloat:1.0]
                 forKey:MPNowPlayingInfoPropertyPlaybackRate];
        //人生进度条: ▓▓▓░░░░░░░░░░░░ 23%
        //歌曲总时间设置
        [dict setObject:[NSNumber numberWithDouble:CMTimeGetSeconds(Player.item.duration)]
                 forKey:MPMediaItemPropertyPlaybackDuration];
        
        NSLog(@"duration:%f",CMTimeGetSeconds(Player.item.duration));
        
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:dict];
    }

    //[self beginReceivingRemoteControlEvents];
    //[self becomeFirstResponder];
}

- (void)dealloca {
    
    Player.player = nil;
    
    [self.item removeObserver:self
                   forKeyPath:@"status"];
    
    [self.item removeObserver:self
                   forKeyPath:@"loadedTimeRanges"];
    
    [self.item removeObserver:self
                   forKeyPath:@"playbackBufferEmpty"];
    
}

/**
 工具函数 用来转换分秒

 @param totalSeconds 传入参数 多少秒
 @return 转换后的时间字符串
 */
NSString * timeFormatted(NSInteger totalSeconds) {
    
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    
    return [NSString stringWithFormat:@"%02d:%02d", minutes, seconds];
}

/**
 根据音乐文件 url 获取专辑图片信息 （没有就返回一个默认图片）
 
 @param url 音乐文件 url
 @return 专辑图片 （如果有的话）
 */
UIImage * GetAlbumImage (NSURL *url) {
    
    UIImage * coverImage = nil;
    
    AVURLAsset *avURLAsset = [[AVURLAsset alloc] initWithURL:url options:nil];
    
    for (NSString *format in [avURLAsset availableMetadataFormats]){
        for (AVMetadataItem *metadata in [avURLAsset metadataForFormat:format]){
            //            if([metadata.commonKey isEqualToString:@"title"]){
            //                NSString *title = (NSString *)metadata.value;//提取歌曲名
            //                NSLog(@"%@",title);
            //            }
            if([metadata.commonKey isEqualToString:@"artwork"]){
                coverImage =  [UIImage imageWithData:(NSData *)metadata.value];//提取图片
                //NSLog(@"%@",coverImage);
                break;
            }
            //还可以提取其他所需的信息
        }
    }
    
    if (!coverImage) {
        coverImage = [UIImage imageNamed:@"logo"];
    }
    
    return coverImage;
}

/**
 根据传入图片 获取毛玻璃图片
 
 @param image 数据图片
 @return 毛玻璃图片
 */
UIImage * GetBlurImage (UIImage * image) {
    
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *inputImage = [CIImage imageWithCGImage:image.CGImage];
    
    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    [filter setValue:[NSNumber numberWithFloat:30.0f] forKey:@"inputRadius"];
    CIImage *result = [filter valueForKey:kCIOutputImageKey];
    
    CGImageRef cgImage = [context createCGImage:result fromRect:[inputImage extent]];
    
    UIImage *returnImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    return returnImage;
}

@end

//- (void)observeValueForKeyPath:(NSString*)keyPath
//                      ofObject:(id)object
//                        change:(NSDictionary *)change
//                       context:(void*)context
//{
//
//    if([keyPath isEqualToString:@"status"]) {
//        //取出status的新值
//        AVPlayerItemStatus status = [change[NSKeyValueChangeNewKey]intValue];
//        [self observeForStatus:status];
//    }
//
//    if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
//        [self observeForLoadedTimeRanges];
//    }
//
//    //这个值是干啥的啊
//    if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
//        NSLog(@"playbackBufferEmpty");
//    }
//
//}

//- (BOOL) isPlaying {
//
//    BOOL playing = NO;
//
//    if (self.player.rate > 0 && self.player.error == nil) {
//        //playing
//        playing = YES;
//    }
//
//    return playing;
//}


/**
 看介绍应该是：
 对缓冲状况进行监听
 但是貌似现在没有卵用 先不玩这个吧 干！写上了就放着吧
 */
//- (void)observeForLoadedTimeRanges {
//
//    NSArray *array = self.item.loadedTimeRanges;
//    CMTimeRange timeRange = [array.firstObject CMTimeRangeValue];//本次缓冲时间范围
//    float startSeconds = CMTimeGetSeconds(timeRange.start);
//    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
//    NSTimeInterval totalBuffer = startSeconds + durationSeconds;//缓冲总长度
//    //NSLog(@"共缓冲：%.2f",totalBuffer);
//    printf("共缓冲：%.2f\n",totalBuffer / CMTimeGetSeconds(self.item.duration));
//
//    //self.loadProgress.progress = totalBuffer / CMTimeGetSeconds(self.item.duration);
//
//}

//- (void)playbackFinished:(NSNotification *)notice {
//
//    NSLog(@"播放完成");
//    //self.playBtn.selected = NO;
//    [self playNext];
////    [self.player play];
//
////    [self resetProgess];
//
////    [self removeObserverAboatItem];
//
//    //移除player监听器
//    //[self removeObserverAboatPlayer];
//
//    //随机一曲
//    //[self randomNextMusic];
//
//}

/**
 移除 item 的各个通知 置空播放状态
 */
//- (void) removeObserverAboatItem {
//    //播放完成即移除通知
//    [[NSNotificationCenter defaultCenter] removeObserver:self
//                                                    name:AVPlayerItemDidPlayToEndTimeNotification
//                                                  object:self.item];
//
//    [self.item removeObserver:self
//                   forKeyPath:@"status"];
//
//    [self.item removeObserver:self
//                   forKeyPath:@"loadedTimeRanges"];
//
//    [self.item removeObserver:self
//                   forKeyPath:@"playbackBufferEmpty"];
//
//}

//- (void)audioSessionInterrupted:(NSNotification *)notification {
//
//    NSLog(@"%@",notification.userInfo);
//
//    AVAudioSessionInterruptionType type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] intValue];
//
//    //收到系统通知 被打断时暂停 被打断结束后 重新play
//    if (type == AVAudioSessionInterruptionTypeBegan) {
//        [self pause];
//    } else {
//        [self pause];
//    }
//
//}

//- (void)remoteControlEventHandler {
//
//    // 直接使用sharedCommandCenter来获取MPRemoteCommandCenter的shared实例
//    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
//
//    // 启用播放命令 (锁屏界面和上拉快捷功能菜单处的播放按钮触发的命令)
//    commandCenter.playCommand.enabled = YES;
//    // 为播放命令添加响应事件, 在点击后触发
//    [commandCenter.playCommand addTarget:self action:@selector(pause)];
//
//    // 播放, 暂停, 上下曲的命令默认都是启用状态, 即enabled默认为YES
//    // 为暂停, 上一曲, 下一曲分别添加对应的响应事件
//    [commandCenter.pauseCommand addTarget:self action:@selector(pause)];
//    //[commandCenter.previousTrackCommand addTarget:self action:@selector(previousTrackAction:)];
//    //[commandCenter.nextTrackCommand addTarget:self action:@selector(nextTrackAction:)];
//
//    // 启用耳机的播放/暂停命令 (耳机上的播放按钮触发的命令)
//    commandCenter.togglePlayPauseCommand.enabled = YES;
//    // 为耳机的按钮操作添加相关的响应事件
//    [commandCenter.togglePlayPauseCommand addTarget:self action:@selector(pause:)];
//}

//- (void) pause {
//
//    [self pause:self.playBtn];
//}
