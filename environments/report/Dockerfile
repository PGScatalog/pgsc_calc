ARG QUARTO_VERSION=1.3.433

FROM continuumio/miniconda3 AS build

ARG QUARTO_VERSION
ARG TARGETARCH

RUN wget https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-${TARGETARCH}.deb && \
    dpkg -i quarto-${QUARTO_VERSION}-linux-${TARGETARCH}.deb && \
    rm quarto-${QUARTO_VERSION}-linux-${TARGETARCH}.deb

RUN conda install -c conda-forge r-renv

COPY renv.lock .

ENV RENV_PATHS_LIBRARY renv/library

RUN R -e "renv::restore(clean=TRUE, prompt=FALSE)"

# RUN conda env export > environment.yml

RUN apt-get update \
    && apt-get install -y procps \
    && rm -rf /var/lib/apt/lists/*

