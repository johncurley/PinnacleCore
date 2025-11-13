#import "EnvironmentControlsBridge.h"
#include "PinnacleMetalRenderer.h"
#import <Foundation/Foundation.h>

@implementation LightingInfo
@end

@implementation EnvironmentControlsBridge {
    PinnacleMetalRenderer* _renderer;
}

- (instancetype)initWithRenderer:(void*)renderer {
    self = [super init];
    if (self) {
        _renderer = static_cast<PinnacleMetalRenderer*>(renderer);
    }
    return self;
}

// MARK: - Lighting Controls

- (void)setLightDirection:(simd_float3)direction {
    if (_renderer) {
        _renderer->setLightDirection(direction);
    }
}

- (void)setLightIntensity:(float)intensity {
    if (_renderer) {
        _renderer->setLightIntensity(intensity);
    }
}

- (void)setLightColor:(simd_float3)color {
    if (_renderer) {
        _renderer->setLightColor(color);
    }
}

- (LightingInfo*)getLightingInfo {
    LightingInfo* info = [[LightingInfo alloc] init];

    if (_renderer) {
        info.direction = _renderer->getLightDirection();
        info.color = _renderer->getLightColor();
        info.intensity = _renderer->getLightIntensity();
    } else {
        info.direction = simd_make_float3(0.5f, -1.0f, 0.5f);
        info.color = simd_make_float3(1.0f, 1.0f, 1.0f);
        info.intensity = 1.0f;
    }

    return info;
}

// MARK: - Environment Controls

- (void)setBackgroundColor:(simd_float4)color {
    if (_renderer) {
        _renderer->setBackgroundColor(color);
    }
}

- (simd_float4)getBackgroundColor {
    if (_renderer) {
        return _renderer->getBackgroundColor();
    }
    return simd_make_float4(0.1f, 0.1f, 0.1f, 1.0f);
}

@end
