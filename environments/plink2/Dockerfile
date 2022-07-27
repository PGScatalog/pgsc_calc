FROM --platform=linux/arm64 debian:stable-slim AS builder-arm64

RUN apt-get update && apt-get install -y build-essential libzstd-dev zlib1g-dev libblas-dev liblapack-dev libatlas-base-dev git

WORKDIR /opt/

ENV PLINK2_VERSION=v2.00a3.3

RUN git clone https://github.com/chrchang/plink-ng.git --branch $PLINK2_VERSION --single-branch

WORKDIR /opt/plink-ng/2.0/build_dynamic

RUN sed -i '/NO_SSE42 =/ s/$/ 1/' Makefile

RUN make -j 5

FROM --platform=linux/amd64 debian:stable-slim AS builder-amd64

RUN apt-get update && apt-get install -y build-essential libzstd-dev zlib1g-dev libblas-dev liblapack-dev libatlas-base-dev git

WORKDIR /opt/

ENV PLINK2_VERSION=v2.00a3.3

RUN git clone https://github.com/chrchang/plink-ng.git --branch $PLINK2_VERSION --single-branch

WORKDIR /opt/plink-ng/2.0/build_dynamic

RUN make -j 5

ARG TARGETARCH

FROM builder-${TARGETARCH} AS copy-bin

FROM debian:stable-slim

RUN apt-get update && apt-get install -y libatlas-base-dev procps && rm -rf /var/lib/apt/lists/*

COPY --from=copy-bin /opt/plink-ng/2.0/build_dynamic/plink2 /usr/local/bin