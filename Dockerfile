FROM lambci/lambda:build-ruby2.5

COPY --from=hashicorp/terraform:0.12.1 /bin/terraform /bin/
COPY . .

ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG TF_VAR_release

RUN sha256sum www/* | sha256sum > www.sha256sum
RUN terraform init
RUN terraform fmt -check
RUN terraform plan -out terraform.tfplan
