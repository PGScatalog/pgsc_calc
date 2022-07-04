# docker buildx build --platform linux/amd64,linux/arm64 --push -t dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/report:2.14 . docker buildx build --platform linux/amd64,linux/arm64 --push -t dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/polars:0.13.46 . --build-arg BUILDKIT_INLINE_CACHE=1

FROM continuumio/miniconda3

WORKDIR /opt/

COPY environment.yml .
RUN conda env create -f environment.yml && conda clean -ay
RUN echo "conda activate report" >> ~/.bashrc
ENV PATH /opt/conda/envs/report/bin:$PATH

