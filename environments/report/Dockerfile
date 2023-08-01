ARG QUARTO_VERSION=1.3.433

FROM r-base:4.3.0

ARG QUARTO_VERSION
ARG TARGETARCH

RUN wget https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-${TARGETARCH}.deb && \
    dpkg -i quarto-${QUARTO_VERSION}-linux-${TARGETARCH}.deb && \
    rm quarto-${QUARTO_VERSION}-linux-${TARGETARCH}.deb
    
RUN R -e 'install.packages(c("DT", "data.table", "purrr", "jsonlite", "dplyr", "ggplot2", "tidyr", "forcats", "readr", "R.utils"), clean=TRUE)'

RUN apt-get update \
    && apt-get install -y procps \
    && rm -rf /var/lib/apt/lists/*