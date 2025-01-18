FROM golang:1.24-alpine3.20@sha256:9fed4022a220fb64327baa90cddfd98607f3b816cb4f5769187500571f73072d

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
