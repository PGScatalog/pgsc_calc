FROM rocker/r-ver:4

ARG QUARTO_VERSION=1.4.550
ARG TARGETARCH

RUN apt-get update \
    && apt-get install -y procps wget zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* 
    
# note: amd64 will get binary packages and install very fast
# https://rocker-project.org/use/extending.html#install-binary-packages
RUN install2.r --error --skipinstalled -n 4 \
    jsonlite \
    dplyr \
    tidyr \
    stringr \
    purrr \
    ggplot2 \
    DT \
    tibble \
    forcats \
    readr \
    && rm -rf /tmp/downloaded_packages \
    && strip /usr/local/lib/R/site-library/*/libs/*.so

RUN wget https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-${TARGETARCH}.deb && \
    dpkg -i quarto-${QUARTO_VERSION}-linux-${TARGETARCH}.deb && \
    rm quarto-${QUARTO_VERSION}-linux-${TARGETARCH}.deb

ENV XDG_CACHE_HOME=/tmp/quarto_cache_home
ENV XDG_DATA_HOME=/tmp/quarto_data_home