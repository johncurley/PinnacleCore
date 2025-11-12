#pragma once

#include <simd/simd.h>
#include "Camera.hpp"

namespace Pinnacle
{
    class InputManager
    {
    public:
        InputManager();
        ~InputManager();

        void mouseDown(simd_float2 point, Pinnacle::Camera& camera);
        void mouseDragged(simd_float2 point, Pinnacle::Camera& camera);
        void mouseUp(simd_float2 point, Pinnacle::Camera& camera);

        // TODO: Add methods for camera control based on mouse input

    private:
        bool m_isMouseDown;
        simd_float2 m_lastMousePosition;
    };
} // namespace Pinnacle
