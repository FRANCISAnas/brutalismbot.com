ARG RUNTIME=ruby2.5

FROM lambci/lambda:build-${RUNTIME} AS install
COPY --from=hashicorp/terraform:0.11.14 /bin/terraform /bin/
COPY . .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION
ARG AWS_SECRET_ACCESS_KEY
RUN terraform init

FROM install AS build
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION
ARG AWS_SECRET_ACCESS_KEY
ARG TF_VAR_release=latest
RUN terraform plan -out terraform.tfplan
