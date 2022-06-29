# syntax = docker/dockerfile:experimental
FROM nvidia/cuda:11.3.1-cudnn8-devel-ubuntu20.04 as devel
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update &&\
    apt-get install -y git python3-pip wget curl

# COPY FROM https://devguide.python.org/setup/#linux
RUN echo 'deb-src http://archive.ubuntu.com/ubuntu/ focal main' >>  /etc/apt/sources.list &&\
    apt-get update &&\
    apt-get build-dep -y python3 && apt-get install -y pkg-config && \
    apt-get install -y build-essential gdb lcov pkg-config \
    libbz2-dev libffi-dev libgdbm-dev libgdbm-compat-dev liblzma-dev \
    libncurses5-dev libreadline6-dev libsqlite3-dev libssl-dev \
    lzma lzma-dev tk-dev uuid-dev zlib1g-dev

ARG PYTHON_VERSION=3.8

# COPY FROM https://github.com/pytorch/pytorch#install-dependencies
RUN curl -fsSL -v -o ~/miniconda.sh -O  https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh  && \
    chmod +x ~/miniconda.sh && \
    ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    /opt/conda/bin/conda install -y python=${PYTHON_VERSION} \
    astunparse numpy ninja pyyaml setuptools cmake cffi typing_extensions future six requests dataclasses \
    mkl mkl-include && \
    /opt/conda/bin/conda install -y -c pytorch magma-cuda110 && \
    /opt/conda/bin/conda clean -ya

ENV PATH /opt/conda/bin:$PATH

RUN apt-get install -y ccache &&\
    /usr/sbin/update-ccache-symlinks &&\
    mkdir /opt/ccache && ccache --set-config=cache_dir=/opt/ccache

COPY ./multipy /src/multipy


RUN --mount=type=cache,target=/opt/ccache \
    cd /src/multipy &&\
    cd multipy/runtime/third-party/pytorch&&\
    mkdir build &&\
    cd build &&\
    cmake \
    -DBUILD_SHARED_LIBS:BOOL=ON \
    -DCMAKE_BUILD_TYPE:STRING=Release \
    -DPYTHON_EXECUTABLE:PATH=`which python3` -DUSE_DEPLOY=ON\
    -DCMAKE_INSTALL_PREFIX:PATH=/opt/libtorch -DTORCH_CUDA_ARCH_LIST="7.0+PTX" .. &&\
    cmake --build . --target install -- -j $(nproc)

RUN --mount=type=cache,target=/opt/ccache \
    cd /src/multipy && \
    mkdir -p build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. &&\
    mkdir -p /opt/multipy &&\
    make DESTDIR=/opt/multipy install -j $(nproc)