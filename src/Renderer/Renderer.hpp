#pragma once

#include "../Core/Scene.hpp"

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
}

namespace Renderer
{
    class Renderer
    {
    public:
        Renderer(MTL::Device* pDevice);
        ~Renderer();

        void draw(MTL::RenderCommandEncoder* pRenderEncoder, Core::Scene& scene);

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
    };
} // namespace Renderer