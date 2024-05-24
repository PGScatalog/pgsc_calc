FROM ubuntu:24.04 AS builder

ARG PLINK_VERSION="2.00a5.10"

RUN apt-get update && apt-get install -y wget build-essential liblapack-dev libatlas-base-dev zlib1g-dev

RUN wget "https://github.com/chrchang/plink-ng/archive/refs/tags/v${PLINK_VERSION}.tar.gz" -P /opt 

WORKDIR /opt/

RUN tar -xvf v${PLINK_VERSION}.tar.gz && \
    cd plink-ng-${PLINK_VERSION}/2.0/build_dynamic && \
    make

FROM ubuntu:24.04

ARG PLINK_VERSION="2.00a5.10"

RUN apt-get update && apt-get -y install liblapack3

COPY --from=builder /opt/plink-ng-${PLINK_VERSION}/2.0/build_dynamic/plink2 /usr/local/bin