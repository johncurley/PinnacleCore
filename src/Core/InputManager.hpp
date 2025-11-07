#pragma once

#include <simd/simd.h>
#include "Camera.hpp"

namespace Core
{
    class InputManager
    {
    public:
        InputManager();
        ~InputManager();

        void mouseDown(simd_float2 point, Core::Camera& camera);
        void mouseDragged(simd_float2 point, Core::Camera& camera);
        void mouseUp(simd_float2 point, Core::Camera& camera);

        // TODO: Add methods for camera control based on mouse input

    private:
        bool m_isMouseDown;
        simd_float2 m_lastMousePosition;
    };
} // namespace Core
