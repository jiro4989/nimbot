FROM nimlang/nim:1.2.0-ubuntu

RUN nimble install -Y \
           jester \
           karax \
           regex \
           ;

RUN nim --version && \
    nimble --version
