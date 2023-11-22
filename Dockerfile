FROM ubuntu:jammy AS o3dbuilder

# For bash-specific commands
SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV CCACHE_VERSION=4.3


ENV DEVELOPER_BUILD=OFF
ENV CCACHE_TAR_NAME=open3d-ci-cpu
ENV PYTHON_VERSION=3.10
ENV BUILD_SHARED_LIBS=ON
ENV BUILD_CUDA_MODULE=OFF
ENV BUILD_TENSORFLOW_OPS=OFF
ENV BUILD_PYTORCH_OPS=OFF
ENV PACKAGE=ON
ENV BUILD_SYCL_MODULE=OFF


RUN apt update && apt install --yes software-properties-common locales && locale-gen en_US en_US.UTF-8 && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 && apt clean && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8

RUN apt update && apt install --yes \
    cmake git nano jq python3 python3-pandas udev libudev-dev libpq-dev python3-pip moreutils libeigen3-dev \
    libboost-all-dev && apt clean && rm -rf /var/lib/apt/lists/*


# Dependencies: basic
RUN apt-get update && apt-get install -y \
    git  \
    wget \
    curl \
    build-essential \
    pkg-config \
 && rm -rf /var/lib/apt/lists/*

# Dependencies: ccache
WORKDIR /tmp

RUN git clone https://github.com/ccache/ccache.git \
 && cd ccache \
 && git checkout v${CCACHE_VERSION} -b ${CCACHE_VERSION} \
 && mkdir build \
 && cd build \
 && cmake -DCMAKE_BUILD_TYPE=Release -DZSTD_FROM_INTERNET=ON .. \
 && make install -j$(nproc) \
 && which ccache \
 && ccache --version

COPY ./util/install_deps_ubuntu.sh ./util/install_deps_ubuntu.sh
# Open3D C++ dependencies
RUN ./util/install_deps_ubuntu.sh assume-yes && rm ./util/install_deps_ubuntu.sh

# Open3D Python dependencies
COPY ./util/ci_utils.sh /tmp/util/ci_utils.sh
COPY ./python/requirements.txt /tmp/python/requirements.txt
RUN source /tmp/util/ci_utils.sh \
 && if [ "${BUILD_CUDA_MODULE}" = "ON" ]; then \
        install_python_dependencies with-cuda with-jupyter; \
    else \
        install_python_dependencies with-jupyter; \
    fi \
 && pip install -r /tmp/python/requirements.txt && rm -f /tmp/python/requirements.txt

# Open3D Jupyter dependencies
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
 && apt-get install -y nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && node --version \
 && npm install -g yarn \
 && yarn --version

RUN rm -rf /tmp/*
WORKDIR /opt/MaxQ/