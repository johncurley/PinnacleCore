#include "InputManager.hpp"
#include "Camera.hpp"
#include <simd/simd.h>
#include <simd/matrix.h>
#include <simd/quaternion.h>

#include <iostream>

namespace Core
{
    InputManager::InputManager()
    :   m_isMouseDown(false)
    {
        m_lastMousePosition = {0.0f, 0.0f};
    }

    InputManager::~InputManager()
    {
    }

    void InputManager::mouseDown(simd_float2 point, Core::Camera& camera)
    {
        m_isMouseDown = true;
        m_lastMousePosition = point;
    }

    void InputManager::mouseDragged(simd_float2 point, Core::Camera& camera)
    {
        if (m_isMouseDown)
        {
            simd_float2 delta = point - m_lastMousePosition;
            camera.orbit(delta.x, delta.y);
            m_lastMousePosition = point;
        }
    }

    void InputManager::mouseUp(simd_float2 point, Core::Camera& camera)
    {
        m_isMouseDown = false;
    }
} // namespace Core
