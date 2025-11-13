#pragma once

#include <simd/simd.h>

static inline simd_float4x4 matrix_from_translation(float x, float y, float z)
{
    return (simd_float4x4){
        (simd_float4){ 1.0f, 0.0f, 0.0f, 0.0f },
        (simd_float4){ 0.0f, 1.0f, 0.0f, 0.0f },
        (simd_float4){ 0.0f, 0.0f, 1.0f, 0.0f },
        (simd_float4){ x, y, z, 1.0f }
    };
}

static inline simd_float4x4 matrix_from_scale(float x, float y, float z)
{
    return (simd_float4x4){
        (simd_float4){ x, 0.0f, 0.0f, 0.0f },
        (simd_float4){ 0.0f, y, 0.0f, 0.0f },
        (simd_float4){ 0.0f, 0.0f, z, 0.0f },
        (simd_float4){ 0.0f, 0.0f, 0.0f, 1.0f }
    };
}
