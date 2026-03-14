.PHONY: build build-local test lint tidy clean docker run-api

GOCMD=go
GOBUILD=$(GOCMD) build
GOTEST=$(GOCMD) test
GOMOD=$(GOCMD) mod

build:
	@echo "Building api-server..."
	CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o bin/api-server ./cmd/api-server

build-local:
	@echo "Building for local..."
	go build -o bin/api-server-mac ./cmd/api-server

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
	docker build -t megav-iptv:latest .

run-api:
	go run ./cmd/api-server -debug -port 8000 -sync -thumbnail-dir ./thumbnails
