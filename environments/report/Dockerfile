FROM r-base:4.3.0 AS quarto_arm64

ONBUILD RUN apt-get update && \
    apt-get install -y gdebi wget

ONBUILD RUN wget https://github.com/quarto-dev/quarto-cli/releases/download/v1.3.302/quarto-1.3.302-linux-arm64.deb && \
    gdebi --non-interactive quarto-1.3.302-linux-arm64.deb && \
    rm quarto-1.3.302-linux-arm64.deb

FROM r-base:4.3.0 AS quarto_amd64

ONBUILD RUN apt-get update && \
    apt-get install -y gdebi wget

ONBUILD RUN wget https://github.com/quarto-dev/quarto-cli/releases/download/v1.3.302/quarto-1.3.302-linux-amd64.deb && \
    gdebi --non-interactive quarto-1.3.302-linux-amd64.deb && \
    rm quarto-1.3.302-linux-amd64.deb
    
FROM quarto_${TARGETARCH}

RUN R -e 'install.packages(c("DT", "data.table", "purrr", "jsonlite", "dplyr", "ggplot2", "tidyr", "forcats", "readr"), clean=TRUE)'

