FROM golang:1.23-alpine3.20@sha256:6a8532e5441593becc88664617107ed567cb6862cb8b2d87eb33b7ee750f653c

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
