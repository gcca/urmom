# syntax=docker/dockerfile:1.7

ARG ALPINE_VERSION=3.23
ARG DEPS_IMAGE=ghcr.io/gcca/urmom-deps:latest
ARG DBMATE_IMAGE=ghcr.io/amacneil/dbmate:2.33.0
ARG GRPC_HEALTH_PROBE_VERSION=v0.4.52

FROM ${DBMATE_IMAGE} AS dbmate

FROM ${DEPS_IMAGE} AS deps

FROM deps AS build

ARG GRPC_HEALTH_PROBE_VERSION
ARG TARGETARCH

WORKDIR /src

RUN apk add --no-cache \
    curl \
    sbcl \
    && curl -fsSLo /tmp/quicklisp.lisp https://beta.quicklisp.org/quicklisp.lisp \
    && sbcl --non-interactive --load /tmp/quicklisp.lisp \
        --eval '(quicklisp-quickstart:install :path "/root/quicklisp/")' \
    && sbcl --non-interactive --load /root/quicklisp/setup.lisp \
        --eval '(ql:quickload (list :sqlite :unix-opts) :silent t)' \
    && rm /tmp/quicklisp.lisp

RUN case "${TARGETARCH}" in \
        amd64|arm64) grpc_probe_arch="${TARGETARCH}" ;; \
        *) echo "unsupported grpc_health_probe architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSLo /usr/local/bin/grpc_health_probe \
        "https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-${grpc_probe_arch}" \
    && chmod +x /usr/local/bin/grpc_health_probe

COPY CMakeLists.txt ./
COPY 3rdparty ./3rdparty
COPY cmd ./cmd
COPY cmake ./cmake
COPY protos ./protos
COPY src ./src

RUN cmake -S . -B build -GNinja -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --parallel "$(nproc)" --target urmom \
    && cp build/libargon2.so /usr/lib/libargon2.so \
    && sbcl --script cmd/build.lisp \
    && mkdir -p /src/cmd-bin \
    && for source in cmd/*.lisp; do \
        name="$(basename "$source" .lisp)"; \
        case "$name" in build|run) continue ;; esac; \
        cp "build/$name" "/src/cmd-bin/$name"; \
    done

FROM alpine:${ALPINE_VERSION} AS execute

RUN apk add --no-cache \
    c-ares \
    ca-certificates \
    grpc-cpp \
    libstdc++ \
    openssl \
    protobuf \
    re2 \
    sqlite \
    sqlite-libs \
    zlib \
    zstd-libs

WORKDIR /app

COPY --from=dbmate /usr/local/bin/dbmate /usr/local/bin/dbmate
COPY --from=build /usr/local/bin/grpc_health_probe /usr/local/bin/grpc_health_probe
COPY --from=build /src/build/urmom /usr/local/bin/urmom
COPY --from=build /src/build/libargon2.so /usr/lib/libargon2.so
COPY --from=build /src/cmd-bin/ /usr/local/bin/
COPY db/migrations/*.sql /app/migrations/
COPY db/fixtures/*.sql /app/fixtures/
COPY docker-entrypoint.sh /usr/local/bin/urmom-entrypoint

RUN chmod +x /usr/local/bin/urmom-entrypoint \
    && mkdir -p data

ENV LD_LIBRARY_PATH=/usr/lib \
    TZ=UTC \
    DB_URL=/app/data/urmom.db \
    PORT=50051 \
    LOAD_SAMPLE_DATA=0

EXPOSE 50051

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD grpc_health_probe -addr=127.0.0.1:${PORT}

ENTRYPOINT ["urmom-entrypoint"]
