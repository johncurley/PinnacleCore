#include "Camera.hpp"

#include <Metal/Metal.hpp>
#include <simd/simd.h>

namespace Core
{
    Camera::Camera()
    :   m_position(simd_make_float3(0.0f, 0.0f, 5.0f)),
        m_lookAt(simd_make_float3(0.0f, 0.0f, 0.0f)),
        m_upVector(simd_make_float3(0.0f, 1.0f, 0.0f)),
        m_fieldOfView(60.0f),
        m_aspectRatio(1.0f),
        m_nearPlane(0.1f),
        m_farPlane(100.0f)
    {
    }

    Camera::~Camera()
    {
    }

    void Camera::setPosition(simd_float3 position)
    {
        m_position = position;
    }

    void Camera::setLookAt(simd_float3 lookAt)
    {
        m_lookAt = lookAt;
    }

    void Camera::setUpVector(simd_float3 upVector)
    {
        m_upVector = upVector;
    }

    void Camera::setFieldOfView(float fieldOfView)
    {
        m_fieldOfView = fieldOfView;
    }

    void Camera::setAspectRatio(float aspectRatio)
    {
        m_aspectRatio = aspectRatio;
    }

    void Camera::setNearPlane(float nearPlane)
    {
        m_nearPlane = nearPlane;
    }

    void Camera::setFarPlane(float farPlane)
    {
        m_farPlane = farPlane;
    }

    simd_float4x4 Camera::getViewMatrix() const
    {
    simd_float3 zAxis = simd_normalize(m_lookAt - m_position);
    simd_float3 xAxis = simd_normalize(simd_cross(m_upVector, zAxis));
    simd_float3 yAxis = simd_cross(zAxis, xAxis);

    simd_float4x4 viewMatrix = {
        simd_make_float4(xAxis.x, yAxis.x, zAxis.x, 0.0f),
        simd_make_float4(xAxis.y, yAxis.y, zAxis.y, 0.0f),
        simd_make_float4(xAxis.z, yAxis.z, zAxis.z, 0.0f),
        simd_make_float4(-simd_dot(xAxis, m_position), -simd_dot(yAxis, m_position), -simd_dot(zAxis, m_position), 1.0f)
    };
    return viewMatrix;
    }

    simd_float4x4 Camera::getProjectionMatrix() const
    {
        float fovRad = m_fieldOfView * (M_PI / 180.0f);
    float yScale = 1.0f / tan(fovRad * 0.5f);
    float xScale = yScale / m_aspectRatio;
    float zRange = m_farPlane - m_nearPlane;
    float zScale = m_farPlane / zRange;
    float zTranslation = -m_nearPlane * m_farPlane / zRange;

    simd_float4x4 perspectiveMatrix = {
        simd_make_float4(xScale, 0.0f, 0.0f, 0.0f),
        simd_make_float4(0.0f, yScale, 0.0f, 0.0f),
        simd_make_float4(0.0f, 0.0f, zScale, 1.0f),
        simd_make_float4(0.0f, 0.0f, zTranslation, 0.0f)
    };
    return perspectiveMatrix;
    }

    void Camera::orbit(float deltaX, float deltaY)
    {
        simd_float3 currentPosition = m_position;
        simd_float3 lookAt = m_lookAt;
        simd_float3 upVector = m_upVector;

        simd_float3 viewDir = simd_normalize(lookAt - currentPosition);
        simd_float3 right = simd_normalize(simd_cross(viewDir, upVector));

        // Rotate around the up vector (Y-axis)
        simd_quatf rotationY = simd_quaternion(deltaX * 0.01f, upVector);
        currentPosition = simd_make_float3(simd_mul(simd_matrix4x4(rotationY), simd_make_float4(currentPosition - lookAt, 1.0f)));
        currentPosition += lookAt;

        // Rotate around the right vector
        simd_quatf rotationX = simd_quaternion(deltaY * 0.01f, right);
        currentPosition = simd_make_float3(simd_mul(simd_matrix4x4(rotationX), simd_make_float4(currentPosition - lookAt, 1.0f)));
        currentPosition += lookAt;

        m_position = currentPosition;
    }
} // namespace Core