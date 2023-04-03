FROM python:3.10.9-slim-bullseye AS quarto_arm64

ONBUILD RUN apt-get update && \
    apt-get install -y procps python3 gcc gdebi wget && \
    rm -rf /var/lib/apt/lists/*

ONBUILD RUN wget https://github.com/quarto-dev/quarto-cli/releases/download/v1.3.302/quarto-1.3.302-linux-arm64.deb && \
    gdebi --non-interactive quarto-1.3.302-linux-arm64.deb && \
    rm quarto-1.3.302-linux-arm64.deb

FROM python:3.10.9-slim-bullseye AS quarto_amd64

ONBUILD RUN apt-get update && \
    apt-get install -y procps python3 gcc gdebi wget && \
    rm -rf /var/lib/apt/lists/*

ONBUILD RUN wget https://github.com/quarto-dev/quarto-cli/releases/download/v1.3.302/quarto-1.3.302-linux-amd64.deb && \
    gdebi --non-interactive quarto-1.3.302-linux-amd64.deb && \
    rm quarto-1.3.302-linux-amd64.deb
    
FROM quarto_${TARGETARCH}

RUN pip install pandas jupyterlab

