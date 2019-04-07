bucket_name = $(shell terraform output bucket_name)
distribution_id = $(shell terraform output cloudfront_distribution_id)
files = $(shell aws s3 ls s3://$(bucket_name)/ | awk '{print $$4}' | sed 's/^/\//g' | tr '\n' ' ')
release ?= $(shell git describe --tags --always)

.PHONY: init plan apply server clean

.terraform:
	docker-compose run --rm terraform init

init: .terraform

plan: init
	docker-compose run --rm -e TF_VAR_release=$(release) terraform plan

apply: init
	docker-compose run --rm -e TF_VAR_release=$(release) terraform apply -auto-approve
	aws cloudfront create-invalidation --distribution-id $(distribution_id) --paths $(files)

server:
	python -m http.server --directory brutalismbot.com

clean:
	rm -rf .terraform
	docker-compose down --volumes
