FROM debian:stable-slim

RUN apt-get update && apt-get install -y ca-certificates

RUN echo "deb https://snapshot.debian.org/archive/debian/20220801T032804Z/ sid main" > /etc/apt/sources.list

RUN apt-get update -o Acquire::Check-Valid-Until=false && apt-get install -y plink2 procps
