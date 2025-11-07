#include "Renderer.hpp"
#include "../Scene/Material.hpp"
#include "../Scene/Texture.hpp"

#include <Metal/Metal.hpp>
#include <QuartzCore/QuartzCore.hpp>

namespace Renderer
{
    Renderer::Renderer(MTL::Device* pDevice)
    :   m_pDevice(pDevice),
        m_pCommandQueue(nullptr),
        m_pShaderLibrary(nullptr),
        m_pRenderPipelineState(nullptr),
        m_pDepthStencilState(nullptr),
        m_pSamplerState(nullptr),
        m_pLightsBuffer(nullptr),
        m_pNumLightsBuffer(nullptr)
    {
        m_pCommandQueue = m_pDevice->newCommandQueue();

        // Load the default shader library
        m_pShaderLibrary = m_pDevice->newDefaultLibrary();

        // Create a render pipeline state object
        MTL::RenderPipelineDescriptor* pPipelineDescriptor = MTL::RenderPipelineDescriptor::alloc()->init();
        pPipelineDescriptor->setVertexFunction(m_pShaderLibrary->newFunction(NS::String::string("vertexShader", NS::UTF8StringEncoding)));
        pPipelineDescriptor->setFragmentFunction(m_pShaderLibrary->newFunction(NS::String::string("fragmentShader", NS::UTF8StringEncoding)));
        pPipelineDescriptor->colorAttachments()->object(0)->setPixelFormat(MTL::PixelFormatBGRA8Unorm_sRGB);
        pPipelineDescriptor->setDepthAttachmentPixelFormat(MTL::PixelFormatDepth32Float);

        NS::Error* pError = nullptr;
        m_pRenderPipelineState = m_pDevice->newRenderPipelineState(pPipelineDescriptor, &pError);
        if (pError)
        {
            __builtin_printf("%s\n", pError->localizedDescription()->utf8String());
        }

        pPipelineDescriptor->release();

        // Create a depth stencil state
        MTL::DepthStencilDescriptor* pDepthStencilDescriptor = MTL::DepthStencilDescriptor::alloc()->init();
        pDepthStencilDescriptor->setDepthCompareFunction(MTL::CompareFunctionLess);
        pDepthStencilDescriptor->setDepthWriteEnabled(true);
        m_pDepthStencilState = m_pDevice->newDepthStencilState(pDepthStencilDescriptor);
        pDepthStencilDescriptor->release();

        // Create a sampler state
        MTL::SamplerDescriptor* pSamplerDescriptor = MTL::SamplerDescriptor::alloc()->init();
        pSamplerDescriptor->setMinFilter(MTL::SamplerMinMagFilterLinear);
        pSamplerDescriptor->setMagFilter(MTL::SamplerMinMagFilterLinear);
        pSamplerDescriptor->setMipFilter(MTL::SamplerMipFilterLinear);
        pSamplerDescriptor->setSAddressMode(MTL::SamplerAddressModeRepeat);
        pSamplerDescriptor->setTAddressMode(MTL::SamplerAddressModeRepeat);
        m_pSamplerState = m_pDevice->newSamplerState(pSamplerDescriptor);
        pSamplerDescriptor->release();
    }

    Renderer::~Renderer()
    {
        m_pSamplerState->release();
        m_pDepthStencilState->release();
        m_pRenderPipelineState->release();
        m_pShaderLibrary->release();
        m_pCommandQueue->release();
        if (m_pLightsBuffer) m_pLightsBuffer->release();
        if (m_pNumLightsBuffer) m_pNumLightsBuffer->release();
    }

    void Renderer::draw(MTL::RenderCommandEncoder* pRenderEncoder, Core::Scene& scene)
    {
        pRenderEncoder->setRenderPipelineState(m_pRenderPipelineState);
        pRenderEncoder->setDepthStencilState(m_pDepthStencilState);
        pRenderEncoder->setFragmentSamplerState(m_pSamplerState, 0);

        // Get camera matrices and position
        simd_float4x4 viewMatrix = scene.getCamera().getViewMatrix();
        simd_float4x4 projectionMatrix = scene.getCamera().getProjectionMatrix();
        simd_float4x4 viewProjectionMatrix = simd_mul(projectionMatrix, viewMatrix);
        simd_float3 cameraPosition = scene.getCamera().getPosition();

        // Handle lights
        const auto& lights = scene.getLights();
        uint32_t numLights = static_cast<uint32_t>(lights.size());

        if (numLights > 0)
        {
            // Ensure buffer is large enough or create it
            if (!m_pLightsBuffer || m_pLightsBuffer->length() < (numLights * sizeof(Core::Scene::Light)))
            {
                if (m_pLightsBuffer) m_pLightsBuffer->release();
                m_pLightsBuffer = m_pDevice->newBuffer(numLights * sizeof(Core::Scene::Light), MTL::ResourceOptionCPUCacheModeWriteCombined);
            }
            memcpy(m_pLightsBuffer->contents(), lights.data(), numLights * sizeof(Core::Scene::Light));
            pRenderEncoder->setFragmentBuffer(m_pLightsBuffer, 0, 2);
        }
        else
        {
            // If no lights, pass a null buffer or a buffer with 0 lights
            pRenderEncoder->setFragmentBuffer(nullptr, 0, 2);
        }

        // Always update numLights buffer
        if (!m_pNumLightsBuffer)
        {
            m_pNumLightsBuffer = m_pDevice->newBuffer(sizeof(uint32_t), MTL::ResourceOptionCPUCacheModeWriteCombined);
        }
        memcpy(m_pNumLightsBuffer->contents(), &numLights, sizeof(uint32_t));
        pRenderEncoder->setFragmentBuffer(m_pNumLightsBuffer, 0, 3);

        // Draw models
        for (const auto& pModel : scene.getModels())
        {
            for (const auto& pNode : pModel->getNodes())
            {
                simd_float4x4 modelMatrix = pNode->getTransformation();

                for (const auto& pMesh : pNode->getMeshes())
                {
                    pRenderEncoder->setVertexBytes(&viewProjectionMatrix, sizeof(simd_float4x4), 0);
                    pRenderEncoder->setVertexBytes(&modelMatrix, sizeof(simd_float4x4), 1);
                    pRenderEncoder->setVertexBuffer(pMesh->getVertexBuffer(), 0, 0);

                    // Set PBR material properties
                    const Scene::PBRMaterial& pbrMaterial = pMesh->getMaterial()->getPBRMaterial();
                    pRenderEncoder->setFragmentBytes(&pbrMaterial, sizeof(Scene::PBRMaterial), 0);
                    pRenderEncoder->setFragmentBytes(&cameraPosition, sizeof(simd_float3), 1);

                    // Bind textures
                    if (pbrMaterial.baseColorTexture) {
                        pRenderEncoder->setFragmentTexture(pbrMaterial.baseColorTexture->getMTLTexture(), 0);
                    }
                    if (pbrMaterial.metallicRoughnessTexture) {
                        pRenderEncoder->setFragmentTexture(pbrMaterial.metallicRoughnessTexture->getMTLTexture(), 1);
                    }
                    if (pbrMaterial.normalTexture) {
                        pRenderEncoder->setFragmentTexture(pbrMaterial.normalTexture->getMTLTexture(), 2);
                    }
                    if (pbrMaterial.occlusionTexture) {
                        pRenderEncoder->setFragmentTexture(pbrMaterial.occlusionTexture->getMTLTexture(), 3);
                    }
                    if (pbrMaterial.emissiveTexture) {
                        pRenderEncoder->setFragmentTexture(pbrMaterial.emissiveTexture->getMTLTexture(), 4);
                    }

                    pRenderEncoder->drawIndexedPrimitives(MTL::PrimitiveTypeTriangle, pMesh->getIndexCount(), MTL::IndexTypeUInt16, pMesh->getIndexBuffer(), 0);
                }
            }
        }
    }
} // namespace Renderer