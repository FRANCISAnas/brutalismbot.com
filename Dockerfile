ARG RUNTIME=ruby2.5

FROM lambci/lambda:build-${RUNTIME} AS build
COPY . .
RUN sha256sum www/* | sha256sum > www.sha256sum

FROM lambci/lambda:build-${RUNTIME} AS test
COPY --from=hashicorp/terraform:0.12.3 /bin/terraform /bin/
COPY --from=build /var/task/ .
RUN terraform fmt -check

FROM lambci/lambda:build-${RUNTIME} AS plan
COPY --from=test /bin/terraform /bin/
COPY --from=test /var/task/ .
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION=us-east-1
ARG AWS_SECRET_ACCESS_KEY
ARG TF_VAR_release
RUN terraform init
RUN terraform plan -out terraform.zip
CMD ["terraform", "apply", "terraform.zip"]
