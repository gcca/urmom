# syntax=docker/dockerfile:1.7

ARG ALPINE_VERSION=3.23
ARG BUILD_JOBS=4
ARG CMAKE_VERSION=4.3.2
ARG GRPC_HEALTH_PROBE_VERSION=v0.4.52

FROM alpine:${ALPINE_VERSION} AS deps

ARG BUILD_JOBS
ARG CMAKE_VERSION
ARG GRPC_HEALTH_PROBE_VERSION
ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG TARGETARCH

# Quicklisp's install runs SBCL, which is unreliable under CPU emulation; build
# each architecture of this image on a native builder.
RUN if [ "${BUILDPLATFORM}" != "${TARGETPLATFORM}" ]; then \
      echo "deps requires a native ${TARGETPLATFORM} builder" >&2; \
      exit 1; \
    fi

ENV CMAKE_BUILD_PARALLEL_LEVEL=${BUILD_JOBS} \
    CMAKE_PREFIX_PATH=/usr \
    LD_LIBRARY_PATH=/usr/lib

RUN apk add --no-cache \
    abseil-cpp-dev \
    build-base \
    c-ares-dev \
    curl \
    git \
    grpc-dev \
    gtest-dev \
    linux-headers \
    ninja-is-really-ninja \
    openssl-dev \
    pkgconf \
    protobuf-c-dev \
    protobuf-dev \
    py3-pip \
    python3 \
    re2-dev \
    sbcl \
    sqlite-dev \
    zlib-dev

RUN python3 -m pip install --break-system-packages --no-cache-dir \
    "cmake==${CMAKE_VERSION}"

RUN case "${TARGETARCH}" in \
        amd64|arm64) grpc_probe_arch="${TARGETARCH}" ;; \
        *) echo "unsupported grpc_health_probe architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSLo /usr/local/bin/grpc_health_probe \
        "https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-${grpc_probe_arch}" \
    && chmod +x /usr/local/bin/grpc_health_probe

# cmd/build.lisp loads ~/quicklisp/setup.lisp, so the path must stay /root/quicklisp.
RUN curl -fsSLo /tmp/quicklisp.lisp https://beta.quicklisp.org/quicklisp.lisp \
    && sbcl --non-interactive --load /tmp/quicklisp.lisp \
        --eval '(quicklisp-quickstart:install :path "/root/quicklisp/")' \
    && sbcl --non-interactive --load /root/quicklisp/setup.lisp \
        --eval '(ql:quickload (list :sqlite :unix-opts) :silent t)' \
    && rm /tmp/quicklisp.lisp
