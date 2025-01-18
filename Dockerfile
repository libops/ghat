FROM golang:1.23-alpine3.20@sha256:def59a601e724ddac5139d447e8e9f7d0aeec25db287a9ee1615134bcda266e2

WORKDIR /app

RUN adduser -S -G nobody ghat

COPY . ./

RUN mkdir -p /vault/secrets && \
  chown -R ghat:nobody /app /vault

RUN apk add --no-cache openssl bash && \
  go mod download && \
  go build -o /app/ghat && \
  go clean -cache -modcache

USER ghat

ENTRYPOINT ["/app/docker-entrypoint.sh"]
