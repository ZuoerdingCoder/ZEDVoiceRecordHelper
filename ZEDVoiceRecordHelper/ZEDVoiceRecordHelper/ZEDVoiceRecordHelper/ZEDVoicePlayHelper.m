//
//  ZEDVoicePlayHelper.m
//  ZEDVoiceRecordHelper
//
//  Created by 超李 on 2017/11/29.
//  Copyright © 2017年 ZED. All rights reserved.
//

#import "ZEDVoicePlayHelper.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "amrFileCodec.h"

@interface ZEDVoicePlayHelper ()<AVAudioPlayerDelegate>

@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, copy) ZEDCompleteHandler complete;
@property (nonatomic, copy) ZEDErrorHandler error;

@property (nonatomic, copy) NSString *lastFilePath;

- (void)p_resetPlayer;

@end

@implementation ZEDVoicePlayHelper

+ (instancetype)instance
{
    static ZEDVoicePlayHelper *player = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        player = [[self alloc] init];
        
        
    });
    return player;
}


- (void)startPlay:(NSString *)filePath :(ZEDCompleteHandler)complete :(ZEDErrorHandler)error
{
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    NSError *setCategoryError = nil;
    if (![session setCategory:AVAudioSessionCategoryPlayback
                  withOptions:AVAudioSessionCategoryOptionMixWithOthers
                        error:&setCategoryError]) {
        // handle error
    }
    
    if ([_player isPlaying]) {
        if ([filePath isEqualToString:_lastFilePath]) {
            _complete(NO);
            return;
        }else{
            _complete(NO);
            
        }
    }
    _lastFilePath = filePath;
    
    [self p_resetPlayer];
    _complete = [complete copy];
    _error = [error copy];
    
    if (filePath) {
        
        NSData *data = DecodeAMRToWAVE( [NSData dataWithContentsOfFile:filePath]);
        
        NSError *error = nil;
        _player = [[AVAudioPlayer alloc] initWithData:data error:&error];
        
        if (error) {
            _error(error);
            return;
        }
        
        [_player prepareToPlay];
        _player.delegate = self;
        _player.volume = 5.0f;
        
        if ([_player play]) {
            NSLog(@"可以播放~");
        }else{
            NSLog(@"不能播放~");
        }
    } else{
        NSLog(@"路径不正确~");
    }
}

- (void)stopPlay
{
    if (_player && _player.isPlaying) {
        [_player stop];
    }
    
}

#pragma mark - player delegate
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    _complete(YES);
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    _error(error);
}


#pragma mark - reset player
- (void)p_resetPlayer
{
    if (_player && _player.isPlaying) {
        [_player stop];
    }
    _player = nil;
}

#pragma mark - isplaying
- (BOOL)isPlaying
{
    return _player.isPlaying;
}

@end
