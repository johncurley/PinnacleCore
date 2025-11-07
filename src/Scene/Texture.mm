#include "Texture.hpp"
#include "../../libs/stb_image.h"

#include <Metal/Metal.hpp>

#include <iostream>

namespace Scene
{
    Texture::Texture(MTL::Device* pDevice, const unsigned char* pData, int width, int height, int channels)
    :   m_pTexture(nullptr)
    {
        // Always use RGBA8Unorm for simplicity and compatibility with stb_image_load(..., STBI_rgb_alpha)
        MTL::PixelFormat pixelFormat = MTL::PixelFormatRGBA8Unorm;
        int bytesPerRow = width * 4; // Assuming 4 bytes per pixel (RGBA)

        MTL::TextureDescriptor* pTextureDescriptor = MTL::TextureDescriptor::texture2DDescriptor(pixelFormat, width, height, false);
        m_pTexture = pDevice->newTexture(pTextureDescriptor);
        pTextureDescriptor->release();

        MTL::Region region = MTL::Region::Make2D(0, 0, width, height);
        m_pTexture->replaceRegion(region, 0, pData, bytesPerRow);
    }

    Texture::Texture(MTL::Device* pDevice, const std::string& path)
    :   m_pTexture(nullptr)
    {
        int width, height, channels;
        stbi_set_flip_vertically_on_load(true);
        // Force loading as RGBA (4 channels) to match Metal's RGBA8Unorm
        unsigned char* data = stbi_load(path.c_str(), &width, &height, &channels, STBI_rgb_alpha);

        if (!data)
        {
            std::cerr << "Failed to load texture: " << path << std::endl;
            return;
        }

        // Use the raw data constructor, passing 4 for channels as we forced STBI_rgb_alpha
        // The assignment operator will handle the m_pTexture member.
        *this = Texture(pDevice, data, width, height, 4);

        stbi_image_free(data);
    }

    Texture::~Texture()
    {
        if (m_pTexture)
        {
            m_pTexture->release();
        }
    }
} // namespace Scene
