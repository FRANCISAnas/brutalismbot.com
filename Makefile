# Project
runtime := ruby2.5
name    := brutalismbot.com
release := $(shell git describe --tags)
build   := $(release)-$(runtime)

# Docker Build
image := brutalismbot/$(name)
digest = $(shell cat build/$(build).build)

dist/$(name)-$(release).tfplan: | build/$(build).build dist
	docker run --rm $(digest) cat /var/task/terraform.tfplan > $@

dist:
	mkdir -p $@

build/$(build).build: | build
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg RUNTIME=$(runtime) \
	--build-arg TF_VAR_release=$(release) \
	--tag $(image):$(build) .
	docker image inspect --format '{{.Id}}' $(image):$(build) > $@

build:
	mkdir -p $@

.PHONY: clean

apply: build/$(build).build
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(digest) \
	terraform apply terraform.tfplan


clean:
	docker rmi -f $(image) $(shell [ -d build ] && cat build/*)
	rm -rf build dist
