#include "Scene.hpp"

namespace Core
{
    Scene::Scene()
    {
    }

    Scene::~Scene()
    {
    }

    void Scene::addModel(std::shared_ptr<::Scene::Model> model)
    {
        m_models.push_back(model);
    }

    const std::vector<std::shared_ptr<::Scene::Model>>& Scene::getModels() const
    {
        return m_models;
    }

    Core::Camera& Scene::getCamera()
    {
        return m_camera;
    }

    void Scene::addLight(const Light& light)
    {
        m_lights.push_back(light);
    }
} // namespace Core
