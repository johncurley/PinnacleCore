#import <Metal/Metal.h>
#import <Foundation/Foundation.h>
#include "Texture.hpp"

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

namespace Pinnacle
{
    Texture::Texture(id device, const std::string& path)
        : m_pTexture(nil), m_width(0), m_height(0)
    {
        id<MTLDevice> mtlDevice = (id<MTLDevice>)device;

        // Load image using stb_image
        int channels;
        unsigned char* imageData = stbi_load(path.c_str(), &m_width, &m_height, &channels, 4); // Force 4 channels (RGBA)

        if (!imageData) {
            NSLog(@"Failed to load texture: %s", path.c_str());
            return;
        }

        // Create texture descriptor
        MTLTextureDescriptor* textureDescriptor = [[MTLTextureDescriptor alloc] init];
        textureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
        textureDescriptor.width = m_width;
        textureDescriptor.height = m_height;
        textureDescriptor.usage = MTLTextureUsageShaderRead;
        textureDescriptor.storageMode = MTLStorageModeManaged;

        // Create texture
        id<MTLTexture> texture = [mtlDevice newTextureWithDescriptor:textureDescriptor];
        [textureDescriptor release];

        if (!texture) {
            NSLog(@"Failed to create Metal texture for: %s", path.c_str());
            stbi_image_free(imageData);
            return;
        }

        // Copy image data to texture
        MTLRegion region = MTLRegionMake2D(0, 0, m_width, m_height);
        [texture replaceRegion:region
                   mipmapLevel:0
                     withBytes:imageData
                   bytesPerRow:m_width * 4];

        m_pTexture = texture;
        stbi_image_free(imageData);
    }

    Texture::Texture(id device, const unsigned char* pData, int width, int height, int channels)
        : m_pTexture(nil), m_width(width), m_height(height)
    {
        id<MTLDevice> mtlDevice = (id<MTLDevice>)device;

        // Create texture descriptor
        MTLTextureDescriptor* textureDescriptor = [[MTLTextureDescriptor alloc] init];
        textureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
        textureDescriptor.width = width;
        textureDescriptor.height = height;
        textureDescriptor.usage = MTLTextureUsageShaderRead;
        textureDescriptor.storageMode = MTLStorageModeManaged;

        // Create texture
        id<MTLTexture> texture = [mtlDevice newTextureWithDescriptor:textureDescriptor];
        [textureDescriptor release];

        if (!texture) {
            NSLog(@"Failed to create Metal texture from memory");
            return;
        }

        // Copy image data to texture
        MTLRegion region = MTLRegionMake2D(0, 0, width, height);
        [texture replaceRegion:region
                   mipmapLevel:0
                     withBytes:pData
                   bytesPerRow:width * 4]; // Assuming RGBA

        m_pTexture = texture;
    }

    Texture::~Texture()
    {
        if (m_pTexture) {
            id<MTLTexture> texture = (id<MTLTexture>)m_pTexture;
            [texture release];
            m_pTexture = nil;
        }
    }
} // namespace Pinnacle
