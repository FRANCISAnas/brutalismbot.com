<img alt="brutalismbot" src="https://brutalismbot.com/banner.png"/>

[![plan](https://img.shields.io/github/workflow/status/brutalismbot/brutalismbot.com/plan?logo=github&style=flat-square)](https://github.com/brutalismbot/brutalismbot.com/actions)


Terraform for hosting [brutalismbot.com](https://www.brutalismbot.com) on AWS CloudFront and S3.

## Development

1. Ensure your AWS keys are properly exported into your environment
2. Run `make` to build a Docker image that contains a planfile for terraform
3. Run `make apply` to apply the configuration to AWS

### See Also

- [Brutalismbot Mail](https://github.com/brutalismbot/mail)
