name     := brutalismbot.com
build    := $(shell git describe --tags --always)
planfile := $(name)-$(build).tfplan

image   := brutalismbot/$(name)
iidfile := .docker/$(build)
digest   = $(shell cat $(iidfile))

$(planfile): www.sha256sum
	docker run --rm $(digest) cat /var/task/$@ > $@

www.sha256sum: $(iidfile)
	docker run --rm $(digest) cat /var/task/$@ > $@

$(iidfile): | .docker
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg PLANFILE=$(planfile) \
	--build-arg TF_VAR_release=$(build) \
	--iidfile $@ \
	--tag $(image):$(build) .

.docker:
	mkdir -p $@

.PHONY: shell apply clean

shell: $(iidfile)
	docker run --rm -it $(digest) /bin/bash

apply: $(iidfile)
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(digest) \
	terraform apply $(planfile)

clean:
	docker image rm -f $(image) $(shell sed G .docker/*)
	rm -rf .docker *.tfplan
