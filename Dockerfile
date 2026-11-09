# Test runtime for the alpha.2 Nextflow integration. Build from this directory:
# docker buildx build --platform linux/amd64 \
#     -t pgscatalog/pgsc_calc:v3-blob --push .
# The workflow and analysis inputs are mounted at runtime, not baked into the image.
FROM condaforge/miniforge3:25.3.1-0

COPY --from=ghcr.io/astral-sh/uv:0.9.8 /uv /usr/local/bin/uv

ARG PYGSCATALOG_COMMIT=9aa7015eb1a46af9e2f88fbb03baeb25a89dbbe7
LABEL org.opencontainers.image.description="PGS Catalog alpha.2 integration test runtime" \
      org.opencontainers.image.source="https://github.com/PGScatalog/pygscatalog" \
      org.opencontainers.image.revision="${PYGSCATALOG_COMMIT}"

# bgen can require compilation; procps is used by Nextflow task monitoring.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential ca-certificates cmake git procps zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Keep every runtime tool on PATH without per-task environment solving.
# Quarto 1.4.550 has no linux-aarch64 build; 1.9.38 supports both architectures.
RUN mamba install -y --override-channels -c conda-forge -c bioconda \
        python=3.12 nextflow=25.10.0 bgen-cpp p7zip \
        'quarto>=1.9.38,<2' r-jsonlite r-dplyr r-tidyr r-stringr r-purrr \
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

ENV NXF_OFFLINE=true
WORKDIR /work
CMD ["/bin/bash"]
