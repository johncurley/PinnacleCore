#ifndef PinnacleMetalRendererInterface_h
#define PinnacleMetalRendererInterface_h

#include <string> // For std::string

// Pure virtual interface for the Metal renderer
class IPinnacleMetalRenderer {
public:
    virtual ~IPinnacleMetalRenderer() {}
    virtual void loadModel(const char* filename) = 0;
    virtual void draw(void* metalLayer) = 0; // Change to void* representing CAMetalLayer*
    // Add other pure virtual methods for rendering, etc.
};

// Factory function to create an instance of the concrete renderer
IPinnacleMetalRenderer* createPinnacleMetalRenderer();

#endif /* PinnacleMetalRendererInterface_h */
