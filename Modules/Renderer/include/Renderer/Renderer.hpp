#pragma once

#include "Core/Scene.hpp"

// Forward declarations for Metal types
namespace MTL
{
    class Device;
    class CommandQueue;
    class Library;
    class RenderPipelineState;
    class DepthStencilState;
    class RenderCommandEncoder;
    class SamplerState;
    class Buffer;
}

namespace Pinnacle
{
    class Renderer
    {
    public:
        Renderer(MTL::Device* pDevice);
        ~Renderer();

        void draw(MTKView* pView);
        void setScene(Scene* pScene);
        void resize(float width, float height);

        MTL::CommandQueue* getCommandQueue() const { return m_pCommandQueue; }

    private:
        MTL::Device* m_pDevice;
        MTL::CommandQueue* m_pCommandQueue;
        MTL::Library* m_pShaderLibrary;
        MTL::RenderPipelineState* m_pRenderPipelineState;
        MTL::DepthStencilState* m_pDepthStencilState;
        MTL::SamplerState* m_pSamplerState;
        MTL::Buffer* m_pLightsBuffer;
        MTL::Buffer* m_pNumLightsBuffer;
        Scene* m_pScene;
    };
} // namespace Pinnacle