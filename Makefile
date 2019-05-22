image   := brutalismbot/brutalismbot.com
images   = $(shell docker image ls --filter reference=$(image) --quiet)
release := $(shell git describe --tags)
runtime := ruby2.5

bucket_name     = $(shell docker-compose run --rm terraform output bucket_name)
distribution_id = $(shell docker-compose run --rm terraform output cloudfront_distribution_id)
paths           = $(shell docker-compose run --rm -T aws s3 ls s3://$(bucket_name)/ | awk '{print $$4}' | sed 's/^/\//g' | tr '\n' ' ')

.PHONY: build apply clean

build:
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg RUNTIME=$(runtime) \
	--build-arg TF_VAR_release=$(release) \
	--tag $(image):$@-$(runtime) \
	--target $@ .

apply: build
	docker run --rm \
	--env AWS_ACCESS_KEY_ID \
	--env AWS_DEFAULT_REGION \
	--env AWS_SECRET_ACCESS_KEY \
	$(image):build-$(runtime) \
	terraform apply terraform.tfplan

clean:
	rm -rf build
	docker rmi -f $(images)
