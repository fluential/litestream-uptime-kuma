IMAGE_NAME := litestream-uptime-kuma
TEST_IMAGE := $(IMAGE_NAME):test

.PHONY: build test clean

build:
	docker build -t $(IMAGE_NAME) .

test: build-test
	bash test/e2e.sh

build-test:
	docker build -t $(TEST_IMAGE) .

clean:
	docker compose -f docker-compose.test.yml down -v --remove-orphans 2>/dev/null || true
	docker rmi $(TEST_IMAGE) 2>/dev/null || true
