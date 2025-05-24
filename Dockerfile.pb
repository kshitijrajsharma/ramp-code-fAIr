# Build instructions:
#   CPU: docker build -f Dockerfile.pb --build-arg BUILD_TYPE=cpu -t ramp-fair:cpu .
#   GPU: docker build -f Dockerfile.pb --build-arg BUILD_TYPE=gpu -t ramp-fair:gpu .

ARG PY_VER=3.10
ARG TF_VER=2.9.2
ARG BUILD_TYPE=cpu
ARG CUDA_TAG=11.8.0-cudnn8-runtime-ubuntu22.04
ARG CUDA_DEVEL_TAG=11.8.0-cudnn8-devel-ubuntu22.04

FROM python:${PY_VER}-slim-bookworm AS cpu-base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential gcc g++ python3-dev python3-rtree \
    gdal-bin libgdal-dev python3-gdal python3-opencv libspatialindex-dev \
    && rm -rf /var/lib/apt/lists/*

FROM nvidia/cuda:${CUDA_DEVEL_TAG} AS cuda-dev

FROM nvidia/cuda:${CUDA_TAG} AS gpu-base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 python3-pip python3-rtree python-is-python3 \
    gdal-bin libgdal-dev python3-gdal python3-opencv \
    libspatialindex-dev libpq-dev \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m pip install --upgrade pip
COPY --from=cuda-dev /usr/local/cuda/nvvm/libdevice /usr/local/cuda/nvvm/libdevice

FROM ${BUILD_TYPE}-base AS builder
ENV DEBIAN_FRONTEND=noninteractive
ARG TF_VER
COPY docker/pipped-requirements.txt /tmp/pipped-requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir --upgrade pip more-itertools && \
    pip install --no-cache-dir tensorflow==${TF_VER} && \
    pip install --no-cache-dir "GDAL==$(gdal-config --version)" && \
    pip install --no-cache-dir -r /tmp/pipped-requirements.txt
COPY solaris /tmp/solaris
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir /tmp/solaris
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir scikit-fmm
COPY setup.py README.md /tmp/ramp-code/
COPY ramp /tmp/ramp-code/ramp
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir /tmp/ramp-code

FROM ${BUILD_TYPE}-base AS final
ENV DEBIAN_FRONTEND=noninteractive
ENV CPLUS_INCLUDE_PATH=/usr/include/gdal \
    C_INCLUDE_PATH=/usr/include/gdal \
    RAMP_HOME=/app
COPY --from=builder /usr/local /usr/local
COPY --from=builder /usr/lib/python*/ /usr/lib/python*/
COPY --from=builder /usr/include/gdal /usr/include/gdal
COPY --from=cuda-dev /usr/local/cuda/nvvm/libdevice /usr/local/cuda/nvvm/libdevice
WORKDIR /app
CMD ["bash"]
