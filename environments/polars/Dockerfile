# docker buildx build --platform linux/amd64,linux/arm64 --push -t dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/polars:0.13.46 . --build-arg BUILDKIT_INLINE_CACHE=1

# this multi-stage build basically builds or grabs wheel files for connector-x, then copies them into a simple conda install of polars and pip installs the wheels
# connector-x doesn't ship arm64 wheels, which is why it needs a complex build
# connector-x is a dependency of polars that allows faster database connections

# arm64 build connectorx wheel -----------------------------------------------------

FROM --platform=linux/arm64 rust AS builder-arm64

WORKDIR /opt/

RUN apt-get update && apt-get install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev git cmake

# need python 3.10 to match prebuilt wheel in builder-amd64

RUN wget https://www.python.org/ftp/python/3.10.5/Python-3.10.5.tgz && \
    tar -xvf Python-3.10.5.tgz

WORKDIR Python-3.10.5

RUN ./configure --enable-optimizations && \
    make -j 5 && \
    make altinstall

ENV PATH="/opt/Python-3.10.5:${PATH}"

RUN python -m pip install poetry 

WORKDIR /opt/

RUN git clone https://github.com/sfu-db/connector-x.git -b v0.3.0

RUN rustup install nightly-2022-04-17 && rustup default nightly-2022-04-17 && rustup override set nightly-2022-04-17

# for some reason cargo install just segfaults

RUN wget https://github.com/casey/just/releases/download/1.2.0/just-1.2.0-aarch64-unknown-linux-musl.tar.gz && \
    mkdir -p just && \
    tar -xvf just-1.2.0-aarch64-unknown-linux-musl.tar.gz -C just

ENV PATH="/opt/just:${PATH}"

WORKDIR connector-x

RUN poetry config experimental.new-installer false

# bootstrapping is slow, but it works... eventually

RUN just bootstrap-python 

# update justfile to use poetry

RUN sed -i 's/\& maturin/\& poetry run maturin/' Justfile && just build-python-wheel

# amd64 build ------------------------------------------------

FROM --platform=linux/amd64 python as builder-amd64

WORKDIR /opt/connector-x/connectorx-python/target/wheels/

RUN pip download connectorx==0.3.0

# prepare builder stages for copying from ---------------------

ARG TARGETARCH

FROM builder-${TARGETARCH} AS copy-wheel

# set up conda environment ------------------------------------

FROM continuumio/miniconda3

WORKDIR /opt/

COPY environment.yml .

RUN conda env create -f environment.yml

RUN echo "conda activate polars" >> ~/.bashrc

ENV PATH /opt/conda/envs/polars/bin:$PATH

# finally, manually install connector-x ---------------------------------

COPY --from=copy-wheel /opt/connector-x/connectorx-python/target/wheels/ .

ARG TARGETARCH

RUN case ${TARGETARCH} in \
         "amd64")  WHEEL=connectorx-0.3.0-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl  ;; \
         "arm64")  WHEEL=connectorx-0.3.0-cp310-cp310-manylinux_2_31_aarch64.whl ;; \
    esac && \
    conda run -n polars pip install $WHEEL --force-reinstall && \
    rm $WHEEL && \
    conda clean -ay

# ayy lmao