FROM python:slim-buster

RUN apt-get update && apt-get install -y procps sqlite3
RUN pip install polars==0.13.15 connectorx>=0.2 pyarrow