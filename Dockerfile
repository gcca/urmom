# syntax=docker/dockerfile:1.7

# Keep in step with deps/Dockerfile: runtime links against its Alpine packages.
ARG ALPINE_VERSION=3.23
ARG BUILD_JOBS=4
ARG DBMATE_IMAGE=ghcr.io/amacneil/dbmate:2.33.0
ARG DEPS_IMAGE=ghcr.io/gcca/urmom:deps

FROM ${DBMATE_IMAGE} AS dbmate

FROM ${DEPS_IMAGE} AS deps

FROM deps AS build

ARG BUILD_JOBS

WORKDIR /src

COPY CMakeLists.txt ./
COPY 3rdparty ./3rdparty
COPY cmake ./cmake
COPY protos ./protos
COPY src ./src

RUN cmake -S . -B build -GNinja -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --parallel "${BUILD_JOBS}" --target urmom

FROM build AS commands

ARG BUILDPLATFORM
ARG TARGETPLATFORM

RUN if [ "${BUILDPLATFORM}" != "${TARGETPLATFORM}" ]; then \
      echo "execute-with-tools requires a native ${TARGETPLATFORM} builder" >&2; \
      exit 1; \
    fi

COPY cmd ./cmd

RUN cp build/libargon2.so /usr/lib/libargon2.so \
    && sbcl --script cmd/build.lisp \
    && mkdir -p /src/cmd-bin \
    && for source in cmd/*.lisp; do \
        name="$(basename "$source" .lisp)"; \
        case "$name" in build|run) continue ;; esac; \
        cp "build/$name" "/src/cmd-bin/$name"; \
    done

FROM alpine:${ALPINE_VERSION} AS runtime

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
    zlib

WORKDIR /app

COPY --from=dbmate /usr/local/bin/dbmate /usr/local/bin/dbmate
COPY --from=build /usr/local/bin/grpc_health_probe /usr/local/bin/grpc_health_probe
COPY --from=build /src/build/urmom /usr/local/bin/urmom
COPY --from=build /src/build/libargon2.so /usr/lib/libargon2.so
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

FROM runtime AS execute-with-tools

RUN apk add --no-cache zstd-libs

COPY --from=commands /src/cmd-bin/ /usr/local/bin/

FROM runtime AS execute
