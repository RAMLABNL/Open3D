cmake_minimum_required(VERSION 3.24)
project(Open3DConsumer LANGUAGES CXX)
find_package(Open3D CONFIG REQUIRED)
if(DEFINED EXPECTED_OPEN3D_VERSION AND
   NOT Open3D_VERSION STREQUAL EXPECTED_OPEN3D_VERSION)
    message(FATAL_ERROR
        "Expected Open3D ${EXPECTED_OPEN3D_VERSION}, found ${Open3D_VERSION}")
endif()
add_executable(open3d-consumer main.cpp)
target_compile_features(open3d-consumer PRIVATE cxx_std_23)
target_link_libraries(open3d-consumer PRIVATE Open3D::Open3D)
enable_testing()
add_test(NAME installed-open3d COMMAND open3d-consumer)
