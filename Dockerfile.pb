# Build instructions:
#   CPU:  docker build --build-arg BUILD_TYPE=cpu -t ramp-fair:cpu .
#   GPU:  docker build --build-arg BUILD_TYPE=gpu -t ramp-fair:gpu .

ARG PY_VER=3.9
ARG TF_VER=2.9.2
ARG BUILD_TYPE=gpu
ARG CUDA_TAG=11.2.2-cudnn8-runtime-ubuntu20.04

# ----- CPU base --------------------------------------------------------------
FROM python:${PY_VER}-slim-bullseye AS cpu-base
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    python${PY_VER}-dev \
    gdal-bin \
    libgdal-dev \
    python3-opencv \
    && rm -rf /var/lib/apt/lists/*

# ----- GPU base --------------------------------------------------------------
FROM nvidia/cuda:${CUDA_TAG} AS gpu-base
ENV DEBIAN_FRONTEND=noninteractive
ARG PY_VER

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    software-properties-common \
    curl \
    build-essential \
    gcc \
    g++ \
    gdal-bin \
    libgdal-dev \
    python3-opencv \
    && add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    python${PY_VER} \
    python${PY_VER}-distutils \
    python${PY_VER}-venv \
    python${PY_VER}-dev \
    && ln -s /usr/bin/python${PY_VER} /usr/local/bin/python3 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python${PY_VER} && \
    rm -rf /var/lib/apt/lists/*

# ----- select base -----------------------------------------------------------
FROM ${BUILD_TYPE}-base AS base
ENV DEBIAN_FRONTEND=noninteractive

# ----- Python: TensorFlow then project deps ----------------------------------
ARG TF_VER
ARG BUILD_TYPE

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir --upgrade pip && \
    if [ "$BUILD_TYPE" = "gpu" ]; then \
    pip install --no-cache-dir tensorflow-gpu==${TF_VER}; \
    else \
    pip install --no-cache-dir tensorflow==${TF_VER}; \
    fi

COPY docker/pipped-requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r pipped-requirements.txt

ENV CPLUS_INCLUDE_PATH=/usr/include/gdal \
    C_INCLUDE_PATH=/usr/include/gdal \
    RAMP_HOME=/app

WORKDIR /app
CMD ["bash"]
