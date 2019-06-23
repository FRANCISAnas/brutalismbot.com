name   := brutalismbot.com
stages := build test plan
build  := $(shell git describe --tags --always)
shells := $(foreach stage,$(stages),shell@$(stage))
digest  = $(shell cat .docker/$(build)$(1))

.PHONY: all apply clean plan test $(shells)

all: www.sha256sum

.docker:
	mkdir -p $@

.docker/$(build)@test: .docker/$(build)@build
.docker/$(build)@plan: .docker/$(build)@test
.docker/$(build)@%: | .docker
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg TF_VAR_release=$(build) \
	--iidfile $@ \
	--tag brutalismbot/$(name):$(build)-$* \
	--target $* .

apply: .docker/$(build)@plan
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(call digest,@plan)

clean:
	-docker image rm -f $(shell awk {print} .docker/*)
	-rm -rf .docker www.sha256sum

plan: test .docker/$(build)@plan

test: all .docker/$(build)@test

www.sha256sum: .docker/$(build)@build
	docker run --rm -w /var/task/ $(call digest,@build) cat $@ > $@

$(shells): shell@%: .docker/$(build)@%
	docker run --rm -it --env-file .env $(call digest,@$*) /bin/bash
