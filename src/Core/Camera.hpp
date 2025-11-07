#pragma once

#include <simd/simd.h>

namespace Core
{
    class Camera
    {
    public:
        Camera();
        ~Camera();

        void setPosition(simd_float3 position);
        void setLookAt(simd_float3 lookAt);
        void setUpVector(simd_float3 upVector);
        void setFieldOfView(float fieldOfView);
        void setAspectRatio(float aspectRatio);
        void setNearPlane(float nearPlane);
        void setFarPlane(float farPlane);

        simd_float4x4 getViewMatrix() const;
        simd_float4x4 getProjectionMatrix() const;

        void orbit(float deltaX, float deltaY);

        simd_float3 getPosition() const { return m_position; }
        simd_float3 getLookAt() const { return m_lookAt; }
        simd_float3 getUpVector() const { return m_upVector; }

    private:
        simd_float3 m_position;
        simd_float3 m_lookAt;
        simd_float3 m_upVector;
        float m_fieldOfView;
        float m_aspectRatio;
        float m_nearPlane;
        float m_farPlane;
    };
} // namespace Core
