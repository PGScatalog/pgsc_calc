FROM continuumio/miniconda3

WORKDIR /opt/

COPY environment.yml .
RUN conda env create -f environment.yml && conda clean -ay
RUN echo "conda activate pyyaml" >> ~/.bashrc
ENV PATH /opt/conda/envs/pyyaml/bin:$PATH
