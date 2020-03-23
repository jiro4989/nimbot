FROM nimlang/nim:1.0.6-ubuntu AS builder

COPY nimbot_server /work
RUN cd /work && nimble install -Y


FROM nimlang/nim:1.0.6-ubuntu AS runtime

COPY --from=builder /root/.nimble/bin/nimbot_server /usr/local/bin/nimbot_server
ENTRYPOINT ["/usr/local/bin/nimbot_server"]

