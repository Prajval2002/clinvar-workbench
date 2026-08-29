FROM quay.io/biocontainers/samtools:1.22.1--h96c455f_0

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget ca-certificates bzip2 \
    && rm -rf /var/lib/apt/lists/*

RUN wget -qO- https://github.com/lh3/bwa/releases/download/v0.7.19/bwa-0.7.19.tar.bz2 \
    | tar -xj \
    && cd bwa-0.7.19 \
    && make -j2 \
    && cp bwa /usr/local/bin/bwa \
    && cd / \
    && rm -rf /bwa-0.7.19

WORKDIR /work
