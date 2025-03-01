FROM golang:1.24-alpine3.20@sha256:79f7ffeff943577c82791c9e125ab806f133ae3d8af8ad8916704922ddcc9dd8

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
