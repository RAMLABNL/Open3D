"""Exercise the backend features used by MaxQ in an isolated wheel installation."""

import ast
import sys
from importlib.metadata import distribution
from pathlib import Path
from tempfile import TemporaryDirectory

import numpy as np
import open3d as o3d


class GeometryConsumer:
    def run(self, expected_version: str) -> None:
        self.check_package(expected_version)
        self.check_mesh_operations()
        self.check_poisson_confidence()
        print("Installed Open3D Python consumer passed")

    def check_package(self, expected_version: str) -> None:
        metadata = distribution("open3d-cpu")
        assert metadata.version == expected_version, metadata.version
        assert o3d.__version__ == expected_version, o3d.__version__
        package_files = {str(path) for path in metadata.files or ()}
        for stub in (
            "open3d/py.typed",
            "open3d/__init__.pyi",
            "open3d/cpu/pybind/geometry/__init__.pyi",
            "open3d/cpu/pybind/t/geometry.pyi",
            "open3d/geometry/__init__.pyi",
            "open3d/t/geometry.pyi",
        ):
            assert stub in package_files, f"Wheel is missing {stub}"
        for stub in metadata.files or ():
            if stub.suffix == ".pyi":
                ast.parse(metadata.locate_file(stub).read_text(), filename=str(stub))
        assert metadata.requires and all(
            requirement.startswith("numpy") for requirement in metadata.requires
        ), metadata.requires
        for feature in (
            "BUILD_VISUALIZATION", "BUILD_GUI", "BUILD_CUDA_MODULE",
            "BUILD_SYCL_MODULE", "BUILD_WEBRTC", "BUNDLE_OPEN3D_ML",
        ):
            assert not o3d._build_config[feature], feature
        assert not hasattr(o3d.visualization, "draw_geometries")

    def check_mesh_operations(self) -> None:
        mesh = o3d.geometry.TriangleMesh.create_sphere(resolution=8)
        tensor_mesh = o3d.t.geometry.TriangleMesh.from_legacy(mesh)
        scene = o3d.t.geometry.RaycastingScene()
        scene.add_triangles(tensor_mesh)
        points = o3d.core.Tensor([[0, 0, 0], [0, 0, 3]], o3d.core.float32)
        np.testing.assert_array_equal(scene.compute_occupancy(points).numpy(), [1, 0])
        assert scene.compute_signed_distance(points).numpy()[0] < 0
        simplified = tensor_mesh.simplify_quadric_decimation(0.5)
        assert 0 < len(simplified.triangle.indices) < len(tensor_mesh.triangle.indices)
        with TemporaryDirectory() as directory:
            path = str(Path(directory) / "sphere.ply")
            assert o3d.t.io.write_triangle_mesh(path, tensor_mesh)
            restored = o3d.t.io.read_triangle_mesh(path)
            np.testing.assert_allclose(restored.vertex.positions.numpy(),
                                       tensor_mesh.vertex.positions.numpy())
        cloud = o3d.geometry.PointCloud(mesh.vertices)
        cloud.estimate_normals()
        feature = o3d.pipelines.registration.compute_fpfh_feature(
            cloud, o3d.geometry.KDTreeSearchParamKNN(knn=20))
        assert feature.data.shape == (33, len(cloud.points))
        result = o3d.pipelines.registration.registration_icp(cloud, cloud, 0.1)
        np.testing.assert_allclose(result.transformation, np.eye(4), atol=1e-6)

    def check_poisson_confidence(self) -> None:
        cloud = o3d.geometry.PointCloud(
            o3d.geometry.TriangleMesh.create_sphere(resolution=10).vertices)
        points = np.asarray(cloud.points)
        normals = points / np.linalg.norm(points, axis=1, keepdims=True)
        cloud.normals = o3d.utility.Vector3dVector(normals)
        plain, plain_density = self.reconstruct(cloud, False)
        scale = np.where(points[:, 2:] > 0, 0.1, 1.0)
        cloud.normals = o3d.utility.Vector3dVector(normals * scale)
        scaled, scaled_density = self.reconstruct(cloud, False)
        np.testing.assert_allclose(plain.vertices, scaled.vertices, atol=1e-5)
        np.testing.assert_allclose(plain_density, scaled_density, atol=1e-5)
        weighted, weighted_density = self.reconstruct(cloud, True)
        assert len(weighted.triangles) > 0
        assert np.isfinite(weighted.vertices).all()
        assert len(weighted_density) == len(weighted.vertices)
        assert len(weighted_density) != len(plain_density) or not np.allclose(
            weighted_density, plain_density, atol=1e-4)

    def reconstruct(
        self, cloud: o3d.geometry.PointCloud, confidence: bool
    ) -> tuple[o3d.geometry.TriangleMesh, o3d.utility.DoubleVector]:
        return o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(
            cloud, depth=4, n_threads=1,
            use_normal_length_as_confidence=confidence)


if __name__ == "__main__":
    GeometryConsumer().run(sys.argv[1])
