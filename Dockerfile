# syntax=docker/dockerfile:1
ARG BASE_IMAGE=maxq-open3d-base:local
FROM ${BASE_IMAGE} AS dependencies
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
       dpkg-dev patchelf libopenblas-pthread-dev liblapacke-dev \
       libeigen3-dev libjsoncpp-dev libjpeg-dev libpng-dev \
       libassimp-dev libzmq3-dev cppzmq-dev libmsgpack-dev libqhull-dev liblzf-dev \
       libtbb-dev libembree-dev \
    && apt-get clean
RUN python3 -m venv /opt/open3d-venv \
    && /opt/open3d-venv/bin/pip install --no-cache-dir \
       setuptools==75.8.0 wheel==0.45.1 numpy==2.2.3 \
       auditwheel==6.4.2 packaging==24.2
ENV PATH=/opt/open3d-venv/bin:${PATH}

FROM dependencies AS build
ARG NPROC=4
ARG OPEN3D_PACKAGE_VERSION
WORKDIR /src/open3d
COPY . .
RUN --mount=type=cache,target=/build,sharing=locked \
    cmake -S . -B /build -G Ninja -C packaging/backend.cmake \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_CXX_STANDARD=23 -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DOPEN3D_RELEASE_VERSION="${OPEN3D_PACKAGE_VERSION:?Pass the version derived from the release tag}" \
        -DPython3_EXECUTABLE=/opt/open3d-venv/bin/python \
    && cmake --build /build --target Open3D pybind --parallel "${NPROC}"
RUN --mount=type=cache,target=/build,sharing=locked \
    cmake --build /build --target pip-package \
    && cpack --config /build/CPackConfig.cmake -G DEB \
       -B /package -D CPACK_OUTPUT_FILE_PREFIX=/package \
    && mkdir -p /artifacts \
    && cp /package/*.deb /artifacts/ \
    && auditwheel repair /build/lib/python_package/pip_package/*.whl \
       --plat manylinux_2_39_x86_64 --wheel-dir /artifacts

FROM ${BASE_IMAGE} AS verify-apt
ARG OPEN3D_PACKAGE_VERSION
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY --from=build /artifacts /artifacts
COPY packaging/consumer /opt/open3d-consumer
COPY packaging/verify.sh /opt/verify-open3d.sh
RUN bash /opt/verify-open3d.sh apt "${OPEN3D_PACKAGE_VERSION}"

FROM ${BASE_IMAGE} AS verify-python
ARG OPEN3D_PACKAGE_VERSION
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
COPY --from=build /artifacts /artifacts
COPY packaging/consumer/check_python.py /opt/open3d-consumer/check_python.py
COPY packaging/verify.sh /opt/verify-open3d.sh
RUN bash /opt/verify-open3d.sh python "${OPEN3D_PACKAGE_VERSION}"

FROM scratch AS artifacts
COPY --from=verify-python /artifacts/ /
COPY --from=verify-apt /verification/apt-passed /apt-passed
COPY --from=verify-python /verification/python-passed /python-passed
