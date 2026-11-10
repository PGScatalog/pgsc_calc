# Offline runtime for the alpha.2 Nextflow integration. Build from this directory:
# docker buildx build --platform linux/amd64 \
#     -t pgscatalog/pgsc_calc:v3-alpha.2 --push .
# The workflow is bundled; analysis inputs and writable work/output directories are mounted.
FROM condaforge/miniforge3:25.3.1-0

COPY --from=ghcr.io/astral-sh/uv:0.9.8 /uv /usr/local/bin/uv

ARG PYGSCATALOG_COMMIT=61ba47b0d115fbbb4707ea81983713d6f077a683
ARG WORKFLOW_REVISION=uncommitted
LABEL org.opencontainers.image.description="PGS Catalog alpha.2 offline workflow" \
      org.opencontainers.image.source="https://github.com/PGScatalog/pgsc_calc" \
      org.opencontainers.image.revision="${WORKFLOW_REVISION}" \
      io.pgscatalog.python.revision="${PYGSCATALOG_COMMIT}"

# bgen can require compilation; procps is used by Nextflow task monitoring.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential ca-certificates cmake git procps zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Keep every runtime tool on PATH without per-task environment solving.
# Pin the report toolchain and export its runtime paths without environment activation.
RUN mamba install -y --override-channels -c conda-forge -c bioconda \
        python=3.12 nextflow=25.10.0 bgen-cpp p7zip \
        'quarto=1.11.9' r-jsonlite r-dplyr r-tidyr r-stringr r-purrr \
        r-ggplot2 r-dt r-tibble r-forcats r-readr \
    && conda list --explicit > /opt/conda-packages.txt \
    && mamba clean -afy

# Fetch and verify the exact stack tip, including its workspace dependency lock.
RUN git init /opt/pygscatalog \
    && git -C /opt/pygscatalog remote add origin https://github.com/PGScatalog/pygscatalog.git \
    && git -C /opt/pygscatalog fetch --depth 1 origin "${PYGSCATALOG_COMMIT}" \
    && git -C /opt/pygscatalog checkout --detach FETCH_HEAD \
    && test "$(git -C /opt/pygscatalog rev-parse HEAD)" = "${PYGSCATALOG_COMMIT}" \
    && printf '%s\n' "${PYGSCATALOG_COMMIT}" > /opt/pygscatalog-commit.txt

ENV UV_PYTHON_DOWNLOADS=never \
    UV_LINK_MODE=copy \
    PYTHONUNBUFFERED=1
WORKDIR /opt/pygscatalog/pgscatalog.utils
RUN uv sync --frozen --no-dev --no-editable --package pgscatalog-utils \
        --python /opt/conda/bin/python \
    && uv pip check --python .venv/bin/python \
    && uv cache clean

ENV PATH="/opt/pygscatalog/pgscatalog.utils/.venv/bin:${PATH}" \
    NXF_HOME=/opt/nextflow

# Match the plugin version in this repository's nextflow.config.
RUN nextflow plugin install nf-schema@2.4.2

ENV QUARTO_DENO=/opt/conda/bin/deno \
    QUARTO_DENO_DOM=/opt/conda/lib/deno_dom.so \
    QUARTO_PANDOC=/opt/conda/bin/pandoc \
    QUARTO_ESBUILD=/opt/conda/bin/esbuild \
    QUARTO_TYPST=/opt/conda/bin/typst \
    QUARTO_TYPST_GATHER=/opt/conda/bin/typst-gather \
    QUARTO_DART_SASS=/opt/conda/bin/sass \
    QUARTO_SHARE_PATH=/opt/conda/share/quarto \
    QUARTO_CONDA_PREFIX=/opt/conda

# Fail the build if the stage entry points or report dependencies are unavailable.
RUN pgsc_calc --help \
    && pgsc_calc load --help \
    && pgsc_calc match --help \
    && pgsc_calc match-combine --help \
    && pgsc_calc score --help \
    && pgsc_calc combine --help \
    && pgscatalog-format --help \
    && command -v bgenix \
    && command -v 7z \
    && nextflow -version \
    && quarto --version \
    && Rscript -e 'for (p in c("jsonlite", "dplyr", "tidyr", "stringr", "purrr", "ggplot2", "DT", "tibble", "forcats", "readr")) library(p, character.only=TRUE)'

COPY main.nf nextflow.config nextflow_schema.json /opt/pgsc_calc/
COPY workflows/pgsc_calc/main.nf /opt/pgsc_calc/workflows/pgsc_calc/main.nf
COPY modules /opt/pgsc_calc/modules
COPY assets /opt/pgsc_calc/assets
COPY bin /opt/pgsc_calc/bin
COPY conf /opt/pgsc_calc/conf
COPY container/pgsc_calc /usr/local/bin/pgsc_calc_workflow
RUN chmod +x /usr/local/bin/pgsc_calc_workflow \
    && printf '%s\n' "$WORKFLOW_REVISION" > /opt/pgsc_calc-revision.txt
ENV NXF_OFFLINE=true
WORKDIR /work
CMD ["/bin/bash"]
