FROM continuumio/miniconda3:22.11.1

ADD environment.yml .

RUN conda env create -f environment.yml

ENV PATH="${PATH}:/opt/conda/envs/zstd/bin/"

RUN conda clean --all -y

WORKDIR /opt/conda

RUN find . -maxdepth 1 -not -name envs -type d -exec rm -r {} \; && rm $HOME/.bashrc

WORKDIR /