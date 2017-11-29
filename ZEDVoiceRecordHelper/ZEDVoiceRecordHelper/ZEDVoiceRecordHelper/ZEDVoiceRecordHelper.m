
//
//  ZEDVoiceRecordHelper.m
//  ZEDVoiceRecordHelper
//
//  Created by 超李 on 2017/11/29.
//  Copyright © 2017年 ZED. All rights reserved.
//

#import "ZEDVoiceRecordHelper.h"
#import <AVFoundation/AVFoundation.h>
#import "amrFileCodec.h"

#define WeakSelf(weakSelf)  __weak __typeof(&*self)weakSelf = self;
#define StrongSelf(strongSelf,weakSelf)  __strong __typeof(&*weakSelf)strongSelf = self;

@interface ZEDVoiceRecordHelper () <AVAudioRecorderDelegate> {
    NSTimer *_timer;
    BOOL _isPause;
}

@property (nonatomic, copy, readwrite) NSString *recordPath;
@property (nonatomic, copy, readwrite) NSString *recordFileName;

@property (nonatomic, copy, readwrite) NSString *tempRecordPath;

@property (nonatomic, readwrite) NSTimeInterval currentTimeInterval;

@property (nonatomic, strong) AVAudioRecorder *recorder;

@end

static const NSInteger kVoiceRecorderTotalTime = 60;

@implementation ZEDVoiceRecordHelper

- (instancetype)init {
    self = [super init];
    if (self) {
        self.maxRecordTime = kVoiceRecorderTotalTime;
        self.recordDuration = @"0";
    }
    return self;
}

- (void)dealloc {
    [self stopRecord];
    self.recordPath = nil;
}


- (void)resetTimer {
    if (!_timer)
    return;
    
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
    
}

- (void)cancelRecording {
    if (!_recorder)
    return;
    
    if (self.recorder.isRecording) {
        [self.recorder stop];
    }
    
    self.recorder = nil;
}

- (void)stopRecord {
    [self cancelRecording];
    [self resetTimer];
}

- (void)prepareRecordingWithPath:(NSString *)path name:(NSString *) name  prepareRecorderCompletion:(ZEDPrepareRecorderCompletion)prepareRecorderCompletion {
    WeakSelf(weakSelf)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        _isPause = NO;
        
        NSError *error = nil;
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory :AVAudioSessionCategoryPlayAndRecord error:&error];
        if(error) {
            NSLog(@"audioSession: %@ %ld %@", [error domain], (long)[error code], [[error userInfo] description]);
            return;
        }
        
        error = nil;
        [audioSession setActive:YES error:&error];
        if(error) {
            NSLog(@"audioSession: %@ %ld %@", [error domain], (long)[error code], [[error userInfo] description]);
            return;
        }
        
        NSMutableDictionary * recordSetting = [NSMutableDictionary dictionary];
        if (self.tranformAMR) {
            [recordSetting setValue :[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey:AVFormatIDKey];
        }else{
            [recordSetting setValue :[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
        }
        [recordSetting setValue:[NSNumber numberWithFloat:8000.0] forKey:AVSampleRateKey];
        [recordSetting setValue:[NSNumber numberWithInt: 1] forKey:AVNumberOfChannelsKey];
        
        if (weakSelf) {
            StrongSelf(strongSelf, weakSelf)
            strongSelf.recordPath = path;
            strongSelf.recordFileName = name;
            error = nil;
            
            if (strongSelf.recorder) {
                [strongSelf cancelRecording];
            } else {
                
                NSString *currentTemp = self.tranformAMR ? self.tempRecordPath : self.recordPath;
                strongSelf.recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:currentTemp] settings:recordSetting error:&error];
                strongSelf.recorder.delegate = strongSelf;
                [strongSelf.recorder prepareToRecord];
                strongSelf.recorder.meteringEnabled = YES;
                //                [strongSelf.recorder recordForDuration:(NSTimeInterval) 160];
            }
            
            if(error) {
                NSLog(@"audioSession: %@ %ld %@", [error domain], (long)[error code], [[error userInfo] description]);
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                //上層如果傳會來說已經取消了, 那這邊就做原先取消的動作
                if (!prepareRecorderCompletion()) {
                    [strongSelf cancelledDeleteWithCompletion:^{
                    }];
                }
            });
        }
    });
}

- (void)startRecordingWithStartRecorderCompletion:(ZEDStartRecorderCompletion)startRecorderCompletion {
    if ([_recorder record]) {
        [self resetTimer];
        _timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(updateMeters) userInfo:nil repeats:YES];
        if (startRecorderCompletion)
        dispatch_async(dispatch_get_main_queue(), ^{
            startRecorderCompletion();
        });
    }
}

- (void)resumeRecordingWithResumeRecorderCompletion:(ZEDResumeRecorderCompletion)resumeRecorderCompletion {
    _isPause = NO;
    if (_recorder) {
        if ([_recorder record]) {
            dispatch_async(dispatch_get_main_queue(), resumeRecorderCompletion);
        }
    }
}

- (void)pauseRecordingWithPauseRecorderCompletion:(ZEDPauseRecorderCompletion)pauseRecorderCompletion {
    _isPause = YES;
    if (_recorder) {
        [_recorder pause];
    }
    if (!_recorder.isRecording)
    dispatch_async(dispatch_get_main_queue(), pauseRecorderCompletion);
}

- (void)stopRecordingWithStopRecorderCompletion:(ZEDStopRecorderCompletion)stopRecorderCompletion {
    _isPause = NO;
    WeakSelf(weakSelf)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf stopRecord];
        NSString *currentTemp = self.tranformAMR ? self.tempRecordPath : self.recordPath;
        [weakSelf getVoiceDuration:currentTemp];
        
        if ([self.recordDuration floatValue] < 1.0) {
            if (currentTemp) {
                // 删除目录下的文件
                NSFileManager *fileManeger = [NSFileManager defaultManager];
                if ([fileManeger fileExistsAtPath:currentTemp]) {
                    NSError *error = nil;
                    BOOL result =[fileManeger removeItemAtPath:currentTemp error:&error];
                    if (result) {
                        NSLog(@"时长：%@，由于小于1秒的音频已删除",self.recordDuration);
                    }
                    if (error) {
                        NSLog(@"error :%@", error.description);
                    }
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                stopRecorderCompletion(NO);
            });
        }else{
            //如果是要格式化的，需要在这里将他格式化
            if (self.tranformAMR) {
                NSData *data = [NSData dataWithContentsOfFile:self.tempRecordPath];
                NSData *amrData = EncodeWAVEToAMR(data, 1, 16);
                // 将amr数据data写入到文件中
                [amrData writeToFile:self.recordPath atomically:YES];
                
                NSFileManager *fileManeger = [NSFileManager defaultManager];
                if ([fileManeger fileExistsAtPath:self.tempRecordPath]) {
                    NSError *error = nil;
                    [fileManeger removeItemAtPath:self.tempRecordPath error:&error];
                    if (error) {
                        NSLog(@"error :%@", error.description);
                    }
                }
                
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                stopRecorderCompletion(YES);
            });
        }
        //        dispatch_async(dispatch_get_main_queue(), stopRecorderCompletion);
    });
    
}

- (void)cancelledDeleteWithCompletion:(ZEDCancellRecorderDeleteFileCompletion)cancelledDeleteCompletion {
    
    _isPause = NO;
    [self stopRecord];
    NSString *currentTemp = self.tranformAMR ? self.tempRecordPath : self.recordPath;
    if (currentTemp) {
        // 删除目录下的文件
        NSFileManager *fileManeger = [NSFileManager defaultManager];
        if ([fileManeger fileExistsAtPath:currentTemp]) {
            NSError *error = nil;
            [fileManeger removeItemAtPath:currentTemp error:&error];
            if (error) {
                NSLog(@"error :%@", error.description);
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                cancelledDeleteCompletion();
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                cancelledDeleteCompletion();
            });
        }
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            cancelledDeleteCompletion();
        });
    }
}

- (void)updateMeters {
    if (!_recorder)
    return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [_recorder updateMeters];
        
        self.currentTimeInterval = _recorder.currentTime;
        
        if (!_isPause) {
            float progress = self.currentTimeInterval / self.maxRecordTime * 1.0;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (_recordProgress) {
                    _recordProgress(progress);
                }
            });
        }
        
        float peakPower = [_recorder averagePowerForChannel:0];
        double ALPHA = 0.015;
        double peakPowerForChannel = pow(10, (ALPHA * peakPower));
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // 更新扬声器
            if (_peakPowerForChannel) {
                _peakPowerForChannel(peakPowerForChannel);
            }
        });
        
        if (self.currentTimeInterval > self.maxRecordTime) {
            [self stopRecord];
            dispatch_async(dispatch_get_main_queue(), ^{
                _maxTimeStopRecorderCompletion(YES);
            });
        }
    });
}

- (void)getVoiceDuration:(NSString*)recordPath {
    NSError *error = nil;
    AVAudioPlayer *play = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:recordPath] error:&error];
    if (error) {
        NSLog(@"recordPath：%@ error：%@", recordPath, error);
        self.recordDuration = @"";
    } else {
        self.recordDuration = [NSString stringWithFormat:@"%.1f", play.duration];
    }
}





#pragma mark - Getter and Setter

-(NSString *)tempRecordPath{
    if (!_tempRecordPath) {
        _tempRecordPath = [NSHomeDirectory() stringByAppendingPathComponent: @"Documents/recording.caf"];
        //        _tempRecordPath = [NSString coro_getFilePathForDirectoriesInDomains:NSDocumentDirectory folderName:@"recording.caf"];
    }
    return _tempRecordPath;
}


-(void)setRecordPath:(NSString *)recordPath{
    if (self.tranformAMR) {
        _recordPath = [NSString stringWithFormat:@"%@.amr",recordPath];
    }else{
        _recordPath = [NSString stringWithFormat:@"%@.acc",recordPath];
    }
    
}

-(void)setRecordFileName:(NSString *)recordFileName{
    if (self.tranformAMR) {
        _recordFileName = [NSString stringWithFormat:@"%@.amr",recordFileName];
    }else{
        _recordFileName = [NSString stringWithFormat:@"%@.acc",recordFileName];
    }
}

@end
