//
//  BGMPlayer.h
//  MycoreText
//
//  Created by Trillion on 2017/4/17.
//  Copyright © 2017年 Trillion. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface BGMPlayer : NSObject

/**
 判断播放器状态

 @return 是否在播放bool值
 */
BOOL isPlaying (void);

/**
 播放音乐

 @param url 音乐路径 可以是网络的
 */
void play (NSURL * url);

/**
 设置播放进度

 @param progress 播放进度
 */
void playRate (float progress);

/**
 循环播放
 */
void playLoop (void);

/**
 缓冲状态监听

 @param block 回调block
 */
void itemStatusCallBack(void (^block) (void));

/**
 缓冲进度监听

 @param block 回调block
 */
void itemLoadingCallBack(void (^block) (void));

/**
 这个empty很神奇 就算是空 也没见响应过 都是状态失败而已

 @param block 回调block
 */
void itemBufferEmptyCallBack(void (^block) (void));

/**
 播放进度监听
 
 @param block 回调block
 */
void duringTimeCallBack(void (^block) (float time , float total));

/**
 播放完成 回调
 
 @param block 回调block
 */
void playFinishedCallBack(void (^block) (void));

/**
 暂停回调

 @param block 回调block
 */
void pauseCallBack(void (^block) (BOOL pauseFlag));

/**
 停止播放
 */
void stop (void);

/**
 播放或暂停
 */
void playOrPause (BOOL pause);

/**
 后台播放 信息配置
 */
void configNowPlayingInfoCenter(void);

/**
 工具函数 用来转换分秒
 
 @param totalSeconds 传入参数 多少秒
 @return 转换后的时间字符串
 */
NSString * timeFormatted(NSInteger totalSeconds);

/**
 根据音乐文件 url 获取专辑图片信息 （没有就返回一个默认图片）
 
 @param url 音乐文件 url
 @return 专辑图片 （如果有的话）
 */
UIImage * GetAlbumImage (NSURL *url) ;

/**
 根据传入图片 获取毛玻璃图片
 
 @param image 数据图片
 @return 毛玻璃图片
 */
UIImage * GetBlurImage (UIImage * image);

@end
