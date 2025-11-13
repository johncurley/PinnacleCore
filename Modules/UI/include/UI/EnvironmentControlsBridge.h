#ifndef EnvironmentControlsBridge_h
#define EnvironmentControlsBridge_h

#import <Foundation/Foundation.h>
#import <simd/simd.h>

/// Lighting information data class
@interface LightingInfo : NSObject

@property (nonatomic, assign) simd_float3 direction;
@property (nonatomic, assign) simd_float3 color;
@property (nonatomic, assign) float intensity;

@end

/// Bridge to expose environment and lighting controls to Swift
@interface EnvironmentControlsBridge : NSObject

/// Initialize with renderer pointer
- (instancetype)initWithRenderer:(void*)renderer;

// Lighting controls
- (void)setLightDirection:(simd_float3)direction;
- (void)setLightIntensity:(float)intensity;
- (void)setLightColor:(simd_float3)color;
- (LightingInfo*)getLightingInfo;

// Environment controls
- (void)setBackgroundColor:(simd_float4)color;
- (simd_float4)getBackgroundColor;

@end

#endif /* EnvironmentControlsBridge_h */
