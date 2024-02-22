FROM rocker/r-ver:4

ARG QUARTO_VERSION=1.4.550
ARG TARGETARCH

RUN apt-get update \
    && apt-get install -y procps \
    && rm -rf /var/lib/apt/lists/* 
    
# note: amd64 will get binary packages and install very fast
# https://rocker-project.org/use/extending.html#install-binary-packages
RUN R -e "install.packages(c('jsonlite', 'dplyr', 'tidyr', 'stringr', 'purrr', 'ggplot2', 'DT', 'tibble', 'forcats'))"

RUN strip /usr/local/lib/R/site-library/*/libs/*.so