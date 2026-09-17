"""Check public Open3D types exposed by the installed wheel."""

from typing import assert_type

import numpy as np
import open3d as o3d
from open3d.geometry import PointCloud
from open3d.t.geometry import RaycastingScene


class TypingConsumer:
    def check_geometry(self) -> None:
        cloud = o3d.geometry.PointCloud()
        assert_type(cloud, PointCloud)
        assert_type(cloud.voxel_down_sample(0.01), PointCloud)
        mesh = o3d.geometry.TriangleMesh.create_sphere()
        assert_type(mesh, o3d.geometry.TriangleMesh)
        tensor_mesh = o3d.t.geometry.TriangleMesh.from_legacy(mesh)
        assert_type(tensor_mesh, o3d.t.geometry.TriangleMesh)
        # Exercise Eigen array arguments, which previously had invalid ndarray types.
        cloud.transform(np.eye(4))
        cloud.scale(1.0, np.zeros(3))
        mesh.rotate(np.eye(3), np.zeros(3))
        scene = o3d.t.geometry.RaycastingScene()
        assert_type(scene, RaycastingScene)
