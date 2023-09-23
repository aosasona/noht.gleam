FROM ghcr.io/gleam-lang/gleam:v0.30.5-erlang-alpine

COPY . /build/

# Install build dependencies
RUN apk add gcc build-base elixir erlang

# Install hex
RUN mix local.hex --force \
    && mix local.rebar --force

# Compile the project
RUN cd /build \
    && gleam export erlang-shipment \
    && mv build/erlang-shipment /app \
    && rm -rf /build

# Remove build dependencies
RUN apk del gcc build-base

# Permissions
RUN addgroup -S noht \
    && adduser -S noht -G noht \
    && chown -R noht /app

# Run the server
USER noht
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
