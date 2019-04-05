release ?= $(shell git describe --tags --always)

.PHONY: init plan apply

.terraform:
	docker-compose run --rm terraform init

init: .terraform

plan: init
	docker-compose run --rm -e TF_VAR_release=$(release) terraform plan

apply: init
	docker-compose run --rm -e TF_VAR_release=$(release) terraform apply -auto-approve

clean:
	rm -rf .terraform
	docker-compose down --volumes
