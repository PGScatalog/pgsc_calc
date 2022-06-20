# docker buildx build --platform linux/amd64,linux/arm64 --push -t dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/plink2:2.00a3 .

FROM debian:stable-slim

RUN apt-get update && apt-get -y install plink2=2.00~a3-210203+dfsg-1+b1 procps
