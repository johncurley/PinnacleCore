#ifndef CameraControlsBridge_h
#define CameraControlsBridge_h

#import <Foundation/Foundation.h>
#import <simd/simd.h>

/// Camera information data class
@interface CameraInfo : NSObject

@property (nonatomic, assign) simd_float3 position;
@property (nonatomic, assign) simd_float3 lookAt;
@property (nonatomic, assign) float distance;
@property (nonatomic, assign) float fieldOfView;  // In degrees

@end

/// Bridge to expose camera controls to Swift
@interface CameraControlsBridge : NSObject

/// Initialize with renderer pointer
- (instancetype)initWithRenderer:(void*)renderer;

/// Reset camera to default view
- (void)resetCamera;

/// Fit camera to frame the loaded model
- (void)fitToModel;

/// Set camera distance from look-at point
- (void)setDistance:(float)distance;

/// Orbit camera around look-at point
- (void)orbitWithDeltaX:(float)deltaX deltaY:(float)deltaY;

/// Get current camera information
- (CameraInfo*)getCameraInfo;

@end

#endif /* CameraControlsBridge_h */
