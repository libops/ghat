FROM golang:1.24-alpine3.20@sha256:00f149d5963f415a8a91943531b9092fde06b596b276281039604292d8b2b9c8

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
