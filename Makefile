bucket_name      = $(shell docker-compose run --rm terraform output bucket_name)
distribution_id  = $(shell docker-compose run --rm terraform output cloudfront_distribution_id)
paths            = $(shell docker-compose run --rm -T aws s3 ls s3://$(bucket_name)/ | awk '{print $$4}' | sed 's/^/\//g' | tr '\n' ' ')
release         := $(shell git describe --tags --always)

.PHONY: init plan apply sync invalidate server clean

default: sync-dryrun plan

.terraform:
	docker-compose run --rm terraform init

init: .terraform

plan: .terraform
	docker-compose run --rm terraform plan -var release=$(release) -out .terraform/$(release).planfile

apply: plan
	docker-compose run --rm terraform apply -auto-approve .terraform/$(release).planfile

sync: .terraform
	docker-compose run --rm aws s3 sync www s3://$(bucket_name)/

sync-dryrun: .terraform
	docker-compose run --rm aws s3 sync www s3://$(bucket_name)/ --dryrun

invalidate:
	docker-compose run --rm aws cloudfront create-invalidation \
		--distribution-id $(distribution_id) \
		--paths $(paths)

server:
	python -m http.server --directory www

clean:
	rm -rf .terraform
