FROM python:3.10.9-slim-bullseye

RUN apt-get update && \
    apt-get -y install procps && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir pyyaml==6.0