FROM ghcr.io/gleam-lang/gleam:v0.30.5-erlang-alpine

COPY . /build/

# Install dependencies required to compile the Gleam application
RUN apk add gcc build-base elixir

# Compile the Gleam application
RUN cd /build \
  && mix local.hex --force \
  && gleam export erlang-shipment \
  && mv build/erlang-shipment /app \
  && rm -r /build

# Clean up deps
RUN apk del gcc build-base elixir

# Permissions
RUN addgroup -S noht \
    && adduser -S noht -G noht \
    && chown -R noht /app

# Run the server
USER noht
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
