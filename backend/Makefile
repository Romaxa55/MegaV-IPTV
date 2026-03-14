.PHONY: build build-local test lint tidy clean docker

GOCMD=go
GOBUILD=$(GOCMD) build
GOTEST=$(GOCMD) test
GOMOD=$(GOCMD) mod

# Build all binaries for Linux
build: build-api-server build-m3u-parser build-epg-parser build-channel-checker build-thumbnail-worker build-github-crawler build-channel-enricher

build-api-server:
	@echo "Building api-server..."
	CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o bin/api-server ./cmd/api-server

build-m3u-parser:
	@echo "Building m3u-parser..."
	CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o bin/m3u-parser ./cmd/m3u-parser

build-epg-parser:
	@echo "Building epg-parser..."
	CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o bin/epg-parser ./cmd/epg-parser

build-channel-checker:
	@echo "Building channel-checker..."
	CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o bin/channel-checker ./cmd/channel-checker

build-thumbnail-worker:
	@echo "Building thumbnail-worker..."
	CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o bin/thumbnail-worker ./cmd/thumbnail-worker

build-github-crawler:
	@echo "Building github-crawler..."
	CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o bin/github-crawler ./cmd/github-crawler

build-channel-enricher:
	@echo "Building channel-enricher..."
	CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o bin/channel-enricher ./cmd/channel-enricher

# Build for local testing (Mac)
build-local:
	@echo "Building all for local..."
	go build -o bin/api-server-mac ./cmd/api-server
	go build -o bin/m3u-parser-mac ./cmd/m3u-parser
	go build -o bin/epg-parser-mac ./cmd/epg-parser
	go build -o bin/channel-checker-mac ./cmd/channel-checker
	go build -o bin/thumbnail-worker-mac ./cmd/thumbnail-worker
	go build -o bin/github-crawler-mac ./cmd/github-crawler
	go build -o bin/channel-enricher-mac ./cmd/channel-enricher

test:
	$(GOTEST) -v ./...

lint:
	golangci-lint run ./...
	gofmt -s -w .
	go vet ./...

tidy:
	$(GOMOD) tidy
	$(GOMOD) verify

clean:
	rm -rf bin/

docker:
	docker build -t iptv-parser:latest .

# Run locally
run-api:
	go run ./cmd/api-server -debug -port 8000

run-parser:
	go run ./cmd/m3u-parser -debug

run-epg:
	go run ./cmd/epg-parser -debug

run-checker:
	go run ./cmd/channel-checker -debug -workers 10 -batch 100

run-crawler:
	go run ./cmd/github-crawler -debug -min-stars 0 -max-age-days 7 -min-channels 5

run-enricher:
	go run ./cmd/channel-enricher
