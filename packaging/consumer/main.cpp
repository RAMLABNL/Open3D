#include <open3d/Open3D.h>
#include <open3d/t/geometry/RaycastingScene.h>

#include <cmath>
#include <iostream>
#include <stdexcept>

class GeometryConsumer {
public:
    void Run() const {
        open3d::utility::LogInfo("Checking Open3D {}", OPEN3D_VERSION);
        CheckRaycasting();
        CheckPoisson();
        std::cout << "Installed Open3D C++ consumer passed\n";
    }

private:
    void CheckRaycasting() const {
        const auto box = open3d::geometry::TriangleMesh::CreateBox();
        auto mesh = open3d::t::geometry::TriangleMesh::FromLegacy(*box);
        open3d::t::geometry::RaycastingScene scene;
        scene.AddTriangles(mesh);
        const auto distance = scene.ComputeDistance(
                open3d::core::Tensor::Init<float>({{2.f, 0.5f, 0.5f}}));
        if (std::abs(distance.Item<float>() - 1.f) > 1e-5f) {
            throw std::runtime_error("CPU raycasting returned a wrong distance");
        }
    }

    void CheckPoisson() const {
        auto sphere = open3d::geometry::TriangleMesh::CreateSphere(1.0, 8);
        open3d::geometry::PointCloud cloud;
        cloud.points_ = sphere->vertices_;
        for (const auto &point : cloud.points_) {
            cloud.normals_.push_back(point.normalized());
        }
        // Upstream's sixth argument is an integer thread count.
        const auto [mesh, density] =
                open3d::geometry::TriangleMesh::CreateFromPointCloudPoisson(
                        cloud, 4, 0.f, 1.1f, false, 1);
        // Preserve the fork's boolean confidence argument and thread count.
        const auto [weighted, weights] =
                open3d::geometry::TriangleMesh::CreateFromPointCloudPoisson(
                        cloud, 4, 0.f, 1.1f, false, true, 1);
        if (mesh->IsEmpty() || weighted->IsEmpty() ||
            density.size() != mesh->vertices_.size() ||
            weights.size() != weighted->vertices_.size()) {
            throw std::runtime_error("Poisson reconstruction returned invalid output");
        }
    }
};

int main() {
    GeometryConsumer().Run();
}
