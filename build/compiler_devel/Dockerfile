FROM ubuntu:19.10 AS builder

RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends \
            build-essential \
            ca-certificates \
            git \
            && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir /work

WORKDIR /work
RUN git clone --depth 1 https://github.com/nim-lang/Nim && \
    cd Nim && \
    bash build_all.sh

FROM ubuntu:19.10 AS runtime

RUN apt-get update -yqq && \
    apt-get install -yqq --no-install-recommends \
            build-essential \
            ca-certificates \
            git \
            && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /work/Nim/bin/* /bin/

RUN nim --version && \
    nimble --version

RUN nimble install -Y \
           jester \
           karax \
           regex \
           ;

