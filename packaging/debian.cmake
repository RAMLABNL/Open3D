set(CPACK_GENERATOR DEB)
set(CPACK_DEBIAN_PACKAGE_NAME open3d)
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "RAMLAB")
set(CPACK_DEBIAN_PACKAGE_DESCRIPTION
    "Open3D CPU geometry library with normal-confidence Poisson reconstruction")
set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
# Public CMake targets expose these header-only/development interfaces.
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libeigen3-dev")
set(CPACK_DEBIAN_PACKAGE_SECTION libs)
