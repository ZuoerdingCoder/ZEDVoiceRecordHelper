//
//  ZEDVoiceRecordHelper.h
//  ZEDVoiceRecordHelper
//
//  ZEDeated by 超李 on 2017/11/29.
//  Copyright © 2017年 ZED. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef BOOL(^ZEDPrepareRecorderCompletion) (void);
typedef void(^ZEDStartRecorderCompletion) (void);
typedef void(^ZEDStopRecorderCompletion) (BOOL hasSuccess);
typedef void(^ZEDPauseRecorderCompletion) (void);
typedef void(^ZEDResumeRecorderCompletion) (void);
typedef void(^ZEDCancellRecorderDeleteFileCompletion) (void);
typedef void(^ZEDRecordProgress) (float progress);
typedef void(^ZEDPeakPowerForChannel) (float peakPowerForChannel);

@interface ZEDVoiceRecordHelper : NSObject

@property (nonatomic, copy) ZEDStopRecorderCompletion maxTimeStopRecorderCompletion;
@property (nonatomic, copy) ZEDRecordProgress recordProgress;
@property (nonatomic, copy) ZEDPeakPowerForChannel peakPowerForChannel;

@property (nonatomic, copy, readonly) NSString *recordPath;
@property (nonatomic, copy, readonly) NSString *recordFileName;

@property (nonatomic, copy) NSString *recordDuration;

@property (nonatomic, assign) NSTimeInterval maxRecordTime; // 默认 60秒为最大
@property (nonatomic, assign, readonly) NSTimeInterval currentTimeInterval;

@property (nonatomic, assign) BOOL tranformAMR;


- (void)prepareRecordingWithPath:(NSString *)path name:(NSString *) name prepareRecorderCompletion:(ZEDPrepareRecorderCompletion)prepareRecorderCompletion;
- (void)startRecordingWithStartRecorderCompletion:(ZEDStartRecorderCompletion)startRecorderCompletion;
- (void)pauseRecordingWithPauseRecorderCompletion:(ZEDPauseRecorderCompletion)pauseRecorderCompletion;
- (void)resumeRecordingWithResumeRecorderCompletion:(ZEDResumeRecorderCompletion)resumeRecorderCompletion;
- (void)stopRecordingWithStopRecorderCompletion:(ZEDStopRecorderCompletion)stopRecorderCompletion;
- (void)cancelledDeleteWithCompletion:(ZEDCancellRecorderDeleteFileCompletion)cancelledDeleteCompletion;

@end
