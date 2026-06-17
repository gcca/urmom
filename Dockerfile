# syntax=docker/dockerfile:1.7

ARG ALPINE_VERSION=3.23
ARG DEPS_IMAGE=ghcr.io/gcca/urmom-deps:latest
ARG DBMATE_IMAGE=ghcr.io/amacneil/dbmate:2.33.0

FROM ${DBMATE_IMAGE} AS dbmate

FROM ${DEPS_IMAGE} AS deps

FROM deps AS build

WORKDIR /src

COPY CMakeLists.txt ./
COPY 3rdparty ./3rdparty
COPY cmake ./cmake
COPY protos ./protos
COPY src ./src

RUN cmake -S . -B build -GNinja -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --parallel "$(nproc)" --target urmom

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
    zlib

WORKDIR /app

COPY --from=dbmate /usr/local/bin/dbmate /usr/local/bin/dbmate
COPY --from=build /src/build/urmom /usr/local/bin/urmom
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

ENTRYPOINT ["urmom-entrypoint"]
