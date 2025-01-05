FROM golang:1.23-alpine3.20

WORKDIR /app

RUN adduser -S -G nobody ghat

COPY . ./

RUN chown -R ghat:nobody /app

RUN go mod download && \
  go build -o /app/ghat && \
  go clean -cache -modcache

USER ghat

ENTRYPOINT ["/app/ghat"]
