FROM continuumio/miniconda3

WORKDIR /opt/

COPY environment.yml .
RUN conda env create -f environment.yml && conda clean -ay
RUN echo "conda activate report" >> ~/.bashrc
ENV PATH /opt/conda/envs/report/bin:$PATH

