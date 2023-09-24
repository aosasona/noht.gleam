FROM ghcr.io/gleam-lang/gleam:v0.30.5-erlang-alpine

COPY . /build/

# Compile the Gleam application
RUN cd /build \
  && apk add gcc build-base elixir \
  && mix local.hex --force \
  && gleam export erlang-shipment \
  && mv build/erlang-shipment /app \
  && rm -r /build \
  && apk del gcc build-base

# Permissions
RUN addgroup -S noht \
    && adduser -S noht -G noht \
    && chown -R noht /app

# Run the server
USER noht
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
