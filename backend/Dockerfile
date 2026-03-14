# ===== BUILDER STAGE =====
FROM golang:1.24-alpine AS builder

RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download && go mod verify

ARG CACHEBUST=1
COPY . .

RUN GOMAXPROCS=$(nproc) && \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o api-server cmd/api-server/main.go & \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o m3u-parser cmd/m3u-parser/main.go & \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o epg-parser cmd/epg-parser/main.go & \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o channel-checker cmd/channel-checker/main.go & \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o thumbnail-worker cmd/thumbnail-worker/main.go & \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o github-crawler cmd/github-crawler/main.go & \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o channel-enricher cmd/channel-enricher/main.go & \
    wait

# ===== FINAL STAGE =====
FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata ffmpeg

RUN adduser -D -s /bin/sh iptv && \
    mkdir -p /app/bin /app/migrations /app/thumbnails

WORKDIR /app

COPY --from=builder /app/api-server ./bin/
COPY --from=builder /app/m3u-parser ./bin/
COPY --from=builder /app/epg-parser ./bin/
COPY --from=builder /app/channel-checker ./bin/
COPY --from=builder /app/thumbnail-worker ./bin/
COPY --from=builder /app/github-crawler ./bin/
COPY --from=builder /app/channel-enricher ./bin/
COPY migrations/ ./migrations/

RUN chown -R iptv:iptv /app && \
    chmod +x ./bin/*

USER iptv

ENTRYPOINT ["./bin/api-server"]
CMD ["-port", "8080"]
