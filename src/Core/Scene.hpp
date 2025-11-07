#pragma once

#include "Camera.hpp"
#include "../Scene/Model.hpp"

#include <vector>
#include <memory>

namespace Core
{
    class Scene
    {
    public:
        Scene();
        ~Scene();

        void addModel(std::shared_ptr<::Scene::Model> model);
        const std::vector<std::shared_ptr<::Scene::Model>>& getModels() const;

        Core::Camera& getCamera();

        struct Light
        {
            simd_float3 direction;
            simd_float3 color;
            float intensity;
        };

        void addLight(const Light& light);
        const std::vector<Light>& getLights() const { return m_lights; }

    private:
        Core::Camera m_camera;
        std::vector<std::shared_ptr<::Scene::Model>> m_models;
        std::vector<Light> m_lights;
        // TODO: Add lights, etc.
    };
} // namespace Core
