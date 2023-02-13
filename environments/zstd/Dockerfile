FROM debian:bullseye-slim

RUN apt-get update && \
    apt-get -y install zstd=1.4.8+dfsg-2.1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
