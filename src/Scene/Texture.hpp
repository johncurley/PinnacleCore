#pragma once

#include <string>
#include <vector>

// Forward declarations for Metal types
namespace MTL
{
    class Device;
    class Texture;
}

namespace Scene
{
    class Texture
    {
    public:
        Texture(MTL::Device* pDevice, const std::string& path);
        Texture(MTL::Device* pDevice, const unsigned char* pData, int width, int height, int channels);
        ~Texture();

        MTL::Texture* getMTLTexture() const { return m_pTexture; }

    private:
        MTL::Texture* m_pTexture;
    };
} // namespace Scene
