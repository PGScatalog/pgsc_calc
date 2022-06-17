# docker buildx build --platform linux/amd64,linux/arm64 --push -t dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/polars:0.13.46 .

FROM continuumio/miniconda3

WORKDIR /opt/

COPY environment.yml .
RUN conda env create -f environment.yml
RUN echo "conda activate polars" >> ~/.bashrc
ENV PATH /opt/conda/envs/polars/bin:$PATH


