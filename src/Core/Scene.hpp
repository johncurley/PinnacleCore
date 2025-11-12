#pragma once

#include "Camera.hpp"
#include "../Scene/Model.hpp"

#include <vector>
#include <memory>

namespace Pinnacle
{
    class Scene
    {
    public:
        Scene();
        ~Scene();

        void addModel(std::shared_ptr<Pinnacle::Model> model);
        const std::vector<std::shared_ptr<Pinnacle::Model>>& getModels() const;

        Pinnacle::Camera& getCamera();
        void setCamera(Pinnacle::Camera* pCamera);

        struct Light
        {
            simd_float3 direction;
            simd_float3 color;
            float intensity;
        };

        void addLight(const Light& light);
        const std::vector<Light>& getLights() const { return m_lights; }

    private:
        Pinnacle::Camera* m_pCamera;
        std::vector<std::shared_ptr<Pinnacle::Model>> m_models;
        std::vector<Light> m_lights;
        // TODO: Add lights, etc.
    };
} // namespace Pinnacle
