# Local candidate validation using the already-built runtime, without publication.
# docker build --build-context python=/path/to/pygscatalog/pgscatalog.utils/packages/pgscatalog.calc \
#   --build-arg PYGSCATALOG_COMMIT=<commit> -f tests/v3/Dockerfile -t pgsc_calc:v3-local .
FROM pgscatalog/pgsc_calc@sha256:54f1e17764afe8050b8aa5f37a0559bb6020abce17cd326e82e7a0f76be32ccb
ARG PYGSCATALOG_COMMIT
LABEL io.pgscatalog.python.revision="${PYGSCATALOG_COMMIT}" \
      org.opencontainers.image.source="https://github.com/PGScatalog/pgsc_calc" \
      org.opencontainers.image.revision="uncommitted-local-candidate"
COPY --from=python src/pgscatalog/calc /opt/pygscatalog/pgscatalog.utils/.venv/lib/python3.12/site-packages/pgscatalog/calc
RUN test -n "$PYGSCATALOG_COMMIT" && printf '%s\n' "$PYGSCATALOG_COMMIT" > /opt/pygscatalog-commit.txt
ENV QUARTO_DENO=/opt/conda/bin/deno \
    QUARTO_DENO_DOM=/opt/conda/lib/deno_dom.so \
    QUARTO_PANDOC=/opt/conda/bin/pandoc \
    QUARTO_ESBUILD=/opt/conda/bin/esbuild \
    QUARTO_TYPST=/opt/conda/bin/typst \
    QUARTO_TYPST_GATHER=/opt/conda/bin/typst-gather \
    QUARTO_DART_SASS=/opt/conda/bin/sass \
    QUARTO_SHARE_PATH=/opt/conda/share/quarto \
    QUARTO_CONDA_PREFIX=/opt/conda
COPY main.nf nextflow.config nextflow_schema.json /opt/pgsc_calc/
COPY workflows/pgsc_calc/main.nf /opt/pgsc_calc/workflows/pgsc_calc/main.nf
COPY modules /opt/pgsc_calc/modules
COPY assets /opt/pgsc_calc/assets
COPY bin /opt/pgsc_calc/bin
COPY conf /opt/pgsc_calc/conf
COPY container/pgsc_calc /usr/local/bin/pgsc_calc_workflow
RUN chmod +x /usr/local/bin/pgsc_calc_workflow
