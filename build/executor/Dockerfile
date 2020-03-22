FROM docker:19.03-dind

# Let's start with some basic stuff.
RUN apk add --no-cache alpine-sdk
RUN mkdir -p /nim && \
    curl -sL "http://nim-lang.org/download/nim-1.0.6.tar.xz" | tar xJ --strip-components=1 -C /nim && \
    cd /nim && \
    sh build.sh && \
    rm -r c_code tests

ENV PATH=/nim/bin:~/.nimble/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /nim
RUN nim c -d:release koch.nim && \
    ./koch nimble

RUN nim --version && \
    nimble --version
