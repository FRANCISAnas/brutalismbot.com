terraform {
  required_version = "~> 0.14"

  backend "s3" {
    bucket = "brutalismbot"
    key    = "terraform/brutalismbot.com.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  cert_record = element(tolist(aws_acm_certificate.cert.domain_validation_options), 0)

  tags = {
    App  = "brutalismbot"
    Name = "brutalismbot.com"
    Repo = "https://github.com/brutalismbot/brutalismbot.com"
  }
}

# brutalismbot.com :: SSL

resource "aws_acm_certificate" "cert" {
  domain_name       = "brutalismbot.com"
  tags              = local.tags
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert.fqdn]
}

# brutalismbot.com :: ROUTE53

resource "aws_route53_zone" "website" {
  comment = "HostedZone created by Route53 Registrar"
  name    = "brutalismbot.com"
}

# www.brutalismbot.com :: S3

resource "aws_s3_bucket" "website" {
  acl           = "private"
  bucket        = "www.brutalismbot.com"
  force_destroy = false
  tags          = local.tags

  website {
    error_document = "error.html"
    index_document = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "website" {
  statement {
    sid       = "AllowCloudFront"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::www.brutalismbot.com/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.website.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json
}

# www.brutalismbot.com :: CLOUDFRONT

resource "aws_cloudfront_distribution" "website" {
  aliases             = ["brutalismbot.com", "www.brutalismbot.com"]
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 403
    response_code         = 404
    response_page_path    = "/error.html"
  }

  default_cache_behavior {
    default_ttl            = 86400
    max_ttl                = 31536000
    min_ttl                = 0
    target_origin_id       = aws_s3_bucket.website.bucket
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
    ]
    cached_methods = [
      "GET",
      "HEAD",
    ]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.website.bucket

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.website.cloudfront_access_identity_path
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    minimum_protocol_version = "TLSv1.1_2016"
    ssl_support_method       = "sni-only"
  }
}

resource "aws_cloudfront_origin_access_identity" "website" {
  comment = "access-identity-www.brutalismbot.com.s3.amazonaws.com"
}

# www.brutalismbot.com :: ROUTE53 RECORDS

resource "aws_route53_record" "a" {
  name    = "brutalismbot.com"
  type    = "A"
  zone_id = aws_route53_zone.website.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
  }
}

resource "aws_route53_record" "aaaa" {
  name    = "brutalismbot.com"
  type    = "AAAA"
  zone_id = aws_route53_zone.website.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
  }
}

resource "aws_route53_record" "cert" {
  name    = local.cert_record.resource_record_name
  records = [local.cert_record.resource_record_value]
  ttl     = 300
  type    = local.cert_record.resource_record_type
  zone_id = aws_route53_zone.website.id
}

resource "aws_route53_record" "www_a" {
  name    = "www.brutalismbot.com"
  type    = "A"
  zone_id = aws_route53_zone.website.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
  }
}

resource "aws_route53_record" "www_aaaa" {
  name    = "www.brutalismbot.com"
  type    = "AAAA"
  zone_id = aws_route53_zone.website.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
  }
}

# api.brutalismbot.com :: API GATEWAY V2

resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = "api.brutalismbot.com"
  tags        = local.tags

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.cert.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_route53_record" "us_east_1" {
  # health_check_id = aws_route53_health_check.healthcheck.id
  name           = aws_apigatewayv2_domain_name.api.domain_name
  set_identifier = "us-east-1.${aws_apigatewayv2_domain_name.api.domain_name}"
  type           = "A"
  zone_id        = aws_route53_zone.website.id

  alias {
    evaluate_target_health = true
    name                   = aws_apigatewayv2_domain_name.api.domain_name_configuration.0.target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api.domain_name_configuration.0.hosted_zone_id
  }

  latency_routing_policy {
    region = "us-east-1"
  }
}

# OUTPUTS

output "bucket_name" {
  description = "S3 website bucket name."
  value       = aws_s3_bucket.website.bucket
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.website.id
}
