//
//  ZEDVoicePlayHelper.h
//  ZEDVoiceRecordHelper
//
//  Created by 超李 on 2017/11/29.
//  Copyright © 2017年 ZED. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^ZEDCompleteHandler)(BOOL flag);
typedef void (^ZEDErrorHandler)(NSError *error);

@interface ZEDVoicePlayHelper : NSObject

+ (instancetype)instance;

- (void)startPlay:(NSString *)filePath :(ZEDCompleteHandler)complete :(ZEDErrorHandler)error;

- (void)stopPlay;

- (BOOL)isPlaying;

@end
