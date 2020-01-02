ARG RUNTIME=ruby2.5
ARG TERRAFORM=latest

FROM lambci/lambda:build-${RUNTIME} AS build
COPY . .
RUN sha256sum www/* | sha256sum > www.sha256sum

FROM hashicorp/terraform:${TERRAFORM} AS plan
WORKDIR /var/task/
RUN apk add --no-cache python3 && pip3 install awscli
COPY --from=build /var/task/ .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
RUN terraform fmt -check
RUN terraform init
ARG TF_VAR_release
RUN terraform plan -out terraform.zip
CMD ["apply", "terraform.zip"]
