//
//  TGFlutterPageRender.m
//  Tgclub
//
//  Created by 黎敬茂 on 2021/11/25.
//  Copyright © 2021 Tencent. All rights reserved.
//

#import "TGFlutterPagRender.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <CoreVideo/CoreVideo.h>
#import <UIKit/UIKit.h>
#include <libpag/PAGPlayer.h>
#include <chrono>
#include <mutex>

@interface TGFlutterPagRender()

@property(nonatomic, strong)PAGSurface *surface;

@property(nonatomic, strong)PAGPlayer* player;

@property(nonatomic, strong)PAGFile* pagFile;

@end

static int64_t GetCurrentTimeUS() {
  static auto START_TIME = std::chrono::high_resolution_clock::now();
  auto now = std::chrono::high_resolution_clock::now();
  auto ns = std::chrono::duration_cast<std::chrono::nanoseconds>(now - START_TIME);
  return static_cast<int64_t>(ns.count() * 1e-3);
}

@implementation TGFlutterPagRender
{
    FrameUpdateCallback _callback;
    CADisplayLink *_displayLink;
    int _lastUpdateTs;
    int _repeatCount;
    int64_t start;
}

- (CVPixelBufferRef)copyPixelBuffer {
    int64_t duration = [_player duration];
    int64_t timestamp = GetCurrentTimeUS();
    auto count = (timestamp - start) / duration;
    double value = 0;
    if(duration <= 0){
        duration = 1;
    }
    if (_repeatCount >= 0 && count > _repeatCount) {
        value = 1;
    } else {
        double playTime = (timestamp - start) % duration;
        value = static_cast<double>(playTime) / duration;
    }
    [_player setProgress:value];
    [_player flush];
    CVPixelBufferRef target = [_surface getCVPixelBuffer];
    CVBufferRetain(target);
    return target;
}

- (instancetype)initWithPagName:(NSString*) pagName frameUpdateCallback:(FrameUpdateCallback)callback;
{
    if (self = [super init]) {
        _callback = callback;
        
        NSString* resourcePath = [[NSBundle mainBundle] pathForResource:pagName ofType:@"pag"];
        _pagFile = [PAGFile Load:resourcePath];
        _player = [[PAGPlayer alloc] init];
        [_player setComposition:_pagFile];
        _surface = [PAGSurface MakeFromGPU:CGSizeMake(_pagFile.width, _pagFile.height)];
        [_player setSurface:_surface];
    }
    return self;
}

- (void)startRender
{
    if (!_displayLink) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(update)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    start = GetCurrentTimeUS();
}

- (void)stopRender
{
    if (!_displayLink) {
        [_displayLink invalidate];
        _displayLink = nil;
    }
}

- (void)setRepeatCount:(int)repeatCount{
    _repeatCount = repeatCount;
}

- (CGSize)size{
    return CGSizeMake(_pagFile.width, _pagFile.height);
}

- (void)update
{
    _callback();
}
@end