bucket_name ?= $(shell docker-compose run --rm terraform output bucket_name)
distribution_id ?= $(shell docker-compose run --rm terraform output cloudfront_distribution_id)
paths ?= $(shell aws s3 ls s3://$(bucket_name)/ | awk '{print $$4}' | sed 's/^/\//g' | tr '\n' ' ')
release ?= $(shell git describe --tags --always)

.PHONY: init plan apply invalidate server clean

.terraform:
	docker-compose run --rm terraform init

init: .terraform

plan: init
	docker-compose run --rm -e TF_VAR_release=$(release) terraform plan -out .terraform/planfile

apply: init plan
	docker-compose run --rm -e TF_VAR_release=$(release) terraform apply -auto-approve .terraform/planfile

invalidate:
	aws cloudfront create-invalidation --distribution-id $(distribution_id) --paths $(paths)

server:
	python -m http.server --directory www

clean:
	rm -rf .terraform
	docker-compose down --volumes
