FROM ghcr.io/gleam-lang/gleam:v0.30.5-erlang-alpine

COPY . /build/

# Compile the project
RUN cd /build \
    && gleam export erlang-shipment \
    && mv build/erlang-shipment /app \
    && rm -rf /build

# Run the server
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
