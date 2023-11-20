FROM ubuntu:jammy AS o3dbuilder
ENV DEBIAN_FRONTEND=noninteractive


RUN apt update && apt install --yes software-properties-common locales && locale-gen en_US en_US.UTF-8 && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 && apt clean && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8

RUN apt update && apt install --yes \
    locales curl wget build-essential jq python3 python3-pandas udev libudev-dev libpq-dev python3-pip moreutils libeigen3-dev \
    libboost-all-dev && apt clean && rm -rf /var/lib/apt/lists/*
