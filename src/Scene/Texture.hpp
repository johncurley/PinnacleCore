#pragma once

#include <string>
#include <vector>
#include <memory>
#include <Foundation/NSSharedPtr.hpp>

// Forward declarations for Metal types
namespace MTL
{
    class Device;
    class Texture;
}

namespace NS
{
    using UInteger = unsigned long;
}

namespace Pinnacle
{
    class Texture
    {
    public:
        Texture(MTL::Device* pDevice, const std::string& path);
        Texture(MTL::Device* pDevice, const unsigned char* pData, int width, int height, int channels);
        ~Texture();

        MTL::Texture* getMTLTexture() const { return m_pTexture.get(); }

    private:
        NS::SharedPtr<MTL::Texture> m_pTexture;
    };
} // namespace Pinnacle
