#import "CameraControlsBridge.h"
#include "PinnacleMetalRenderer.h"
#import <Foundation/Foundation.h>

@implementation CameraInfo
@end

@implementation CameraControlsBridge {
    PinnacleMetalRenderer* _renderer;
}

- (instancetype)initWithRenderer:(void*)renderer {
    self = [super init];
    if (self) {
        _renderer = static_cast<PinnacleMetalRenderer*>(renderer);
    }
    return self;
}

- (void)resetCamera {
    if (_renderer) {
        _renderer->resetCamera();
    }
}

- (void)fitToModel {
    if (_renderer) {
        _renderer->fitCameraToModel();
    }
}

- (void)setDistance:(float)distance {
    if (_renderer) {
        _renderer->setCameraDistance(distance);
    }
}

- (void)orbitWithDeltaX:(float)deltaX deltaY:(float)deltaY {
    if (_renderer) {
        _renderer->orbitCamera(deltaX, deltaY);
    }
}

- (CameraInfo*)getCameraInfo {
    CameraInfo* info = [[CameraInfo alloc] init];

    if (_renderer) {
        info.position = _renderer->getCameraPosition();
        info.lookAt = _renderer->getCameraLookAt();
        info.distance = _renderer->getCameraDistance();
        info.fieldOfView = _renderer->getCameraFieldOfView() * (180.0f / 3.14159265359f);  // Convert to degrees
    } else {
        info.position = simd_make_float3(0, 0, 0);
        info.lookAt = simd_make_float3(0, 0, 0);
        info.distance = 0.0f;
        info.fieldOfView = 45.0f;
    }

    return info;
}

@end
