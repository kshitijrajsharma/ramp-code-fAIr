# Define build arg with default as gpu
ARG BASE_IMAGE=tensorflow/tensorflow:2.9.2-gpu

FROM ${BASE_IMAGE} AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    gdal-bin \
    libgdal-dev \
    python3-opencv && \
    rm -rf /var/lib/apt/lists/*

ENV CPLUS_INCLUDE_PATH=/usr/include/gdal \
    C_INCLUDE_PATH=/usr/include/gdal

COPY docker/pipped-requirements.txt /tmp/pipped-requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip pip install --no-cache-dir -r /tmp/pipped-requirements.txt

COPY solaris /tmp/solaris
RUN --mount=type=cache,target=/root/.cache/pip pip install --no-cache-dir /tmp/solaris --use-feature=in-tree-build

RUN --mount=type=cache,target=/root/.cache/pip pip install --no-cache-dir scikit-fmm --use-feature=in-tree-build

COPY setup.py README.md /tmp/ramp-code/
COPY ramp /tmp/ramp-code/ramp
RUN --mount=type=cache,target=/root/.cache/pip pip install --no-cache-dir /tmp/ramp-code --use-feature=in-tree-build

# Use the same base image for the final stage
FROM ${BASE_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
    gdal-bin \
    libgdal-dev \
    python3-opencv && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/include/gdal /usr/include/gdal
COPY --from=builder /usr/lib/python3/dist-packages/ /usr/lib/python3/dist-packages/
COPY --from=builder /usr/local/lib/python3.8/dist-packages/ /usr/local/lib/python3.8/dist-packages/

ENV CPLUS_INCLUDE_PATH=/usr/include/gdal \
    C_INCLUDE_PATH=/usr/include/gdal \
    RAMP_HOME=/tf

WORKDIR /tf

CMD ["bash"]