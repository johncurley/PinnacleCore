#pragma once

#include <string>
#include <vector>
#include <memory>

#ifdef __OBJC__
#import <Metal/Metal.h>
#else
typedef void* id;
#endif

namespace Pinnacle
{
    class Texture
    {
    public:
        Texture(id device, const std::string& path);
        Texture(id device, const unsigned char* pData, int width, int height, int channels);
        ~Texture();

        id getMTLTexture() const { return m_pTexture; }
        int getWidth() const { return m_width; }
        int getHeight() const { return m_height; }

    private:
        id m_pTexture; // id<MTLTexture>
        int m_width;
        int m_height;
    };
} // namespace Pinnacle
