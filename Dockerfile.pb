# Build instructions:
#   CPU: docker build --build-arg BUILD_TYPE=cpu -t ramp-fair:cpu .
#   GPU: docker build --build-arg BUILD_TYPE=gpu -t ramp-fair:gpu .

ARG PY_VER=3.10
ARG TF_VER=2.9.2
ARG BUILD_TYPE=gpu
ARG CUDA_TAG=11.2.2-cudnn8-runtime-ubuntu20.04

# ==============================================================================
# === CPU base image (minimal) =================================================
FROM python:${PY_VER}-slim-bullseye AS cpu-base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential gcc g++ python${PY_VER}-dev \
    gdal-bin libgdal-dev python3-opencv \
    && rm -rf /var/lib/apt/lists/*

# ==============================================================================
# === GPU base image (CUDA + custom Python install) ===========================
FROM nvidia/cuda:${CUDA_TAG} AS gpu-base
ENV DEBIAN_FRONTEND=noninteractive
ARG PY_VER
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    software-properties-common curl build-essential \
    gcc g++ gdal-bin libgdal-dev python3-opencv \
    && add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    python${PY_VER} python${PY_VER}-dev python${PY_VER}-venv \
    python${PY_VER}-distutils \
    && ln -s /usr/bin/python${PY_VER} /usr/local/bin/python3 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python${PY_VER} && \
    rm -rf /var/lib/apt/lists/*

# ==============================================================================
# === Builder stage (installs everything) =====================================
FROM ${BUILD_TYPE}-base AS builder
ENV DEBIAN_FRONTEND=noninteractive
ARG TF_VER
ARG BUILD_TYPE

COPY docker/pipped-requirements.txt /tmp/pipped-requirements.txt

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir --upgrade pip && \
    if [ "$BUILD_TYPE" = "gpu" ]; then \
    pip install --no-cache-dir tensorflow-gpu==${TF_VER}; \
    else \
    pip install --no-cache-dir tensorflow==${TF_VER}; \
    fi && \
    pip install --no-cache-dir -r /tmp/pipped-requirements.txt

# Install solaris (local)
COPY solaris /tmp/solaris
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir /tmp/solaris 

# Install scikit-fmm
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir scikit-fmm 

# Install ramp (local)
COPY setup.py README.md /tmp/ramp-code/
COPY ramp /tmp/ramp-code/ramp
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir /tmp/ramp-code 

# ==============================================================================
# === Final minimal runtime image =============================================
FROM ${BUILD_TYPE}-base AS final
ENV DEBIAN_FRONTEND=noninteractive

ENV CPLUS_INCLUDE_PATH=/usr/include/gdal \
    C_INCLUDE_PATH=/usr/include/gdal \
    RAMP_HOME=/app

COPY --from=builder /usr/local/lib/python3*/dist-packages/ /usr/local/lib/python3*/dist-packages/
COPY --from=builder /usr/lib/python3*/dist-packages/ /usr/lib/python3*/dist-packages/
COPY --from=builder /usr/include/gdal /usr/include/gdal

WORKDIR /app
CMD ["bash"]
