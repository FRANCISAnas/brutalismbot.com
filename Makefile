name     := brutalismbot.com
build    := $(shell git describe --tags --always)
planfile := .terraform/$(build).zip

image   := brutalismbot/$(name)
iidfile := .docker/$(build)
digest   = $(shell cat $(iidfile))

$(planfile): www.sha256sum | .terraform
	docker run --rm $(digest) cat /var/task/terraform.zip > $@

www.sha256sum: $(iidfile)
	docker run --rm $(digest) cat /var/task/$@ > $@

$(iidfile): | .docker
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg TF_VAR_release=$(build) \
	--iidfile $@ \
	--tag $(image):$(build) .

.%:
	mkdir -p $@

.PHONY: shell plan apply clean

shell: $(iidfile) .env
	docker run --rm -it --env-file .env $(digest) /bin/bash

apply: $(iidfile)
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(digest)

clean:
	docker image rm -f $(image) $(shell sed G .docker/*)
	rm -rf .docker .terraform www.sha256sum
