terraform {
  required_version = "~> 0.13"

  backend s3 {
    bucket = "brutalismbot"
    key    = "terraform/brutalismbot.com.tfstate"
    region = "us-east-1"
  }
}

provider aws {
  region  = "us-east-1"
  version = "~> 3.1"
}

locals {
  cert_record = element(tolist(aws_acm_certificate.cert.domain_validation_options), 0)
  domain      = "brutalismbot.com"
  repo        = "https://github.com/brutalismbot/brutalismbot.com"

  tags = {
    App  = "brutalismbot"
    Name = local.domain
    Repo = local.repo
  }
}

data aws_iam_policy_document website {
  statement {
    sid = "AllowCloudFront"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::www.${local.domain}/*",
    ]

    principals {
      type = "AWS"

      identifiers = [
        aws_cloudfront_origin_access_identity.website.iam_arn,
      ]
    }
  }
}

resource aws_acm_certificate cert {
  domain_name       = local.domain
  tags              = local.tags
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource aws_acm_certificate_validation cert {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert.fqdn]
}

resource aws_cloudfront_distribution website {
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"

  aliases = [
    local.domain,
    "www.${local.domain}",
  ]

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

resource aws_cloudfront_origin_access_identity website {
  comment = "access-identity-www.${local.domain}.s3.amazonaws.com"
}

resource aws_route53_record a {
  name    = local.domain
  type    = "A"
  zone_id = aws_route53_zone.website.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
  }
}

resource aws_route53_record aaaa {
  name    = local.domain
  type    = "AAAA"
  zone_id = aws_route53_zone.website.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
  }
}

resource aws_route53_record cert {
  name    = local.cert_record.resource_record_name
  records = [local.cert_record.resource_record_value]
  ttl     = 300
  type    = local.cert_record.resource_record_type
  zone_id = aws_route53_zone.website.id
}

resource aws_route53_record www_a {
  name    = "www.${local.domain}"
  type    = "A"
  zone_id = aws_route53_zone.website.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
  }
}

resource aws_route53_record www_aaaa {
  name    = "www.${local.domain}"
  type    = "AAAA"
  zone_id = aws_route53_zone.website.id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
  }
}

resource aws_route53_zone website {
  comment = "HostedZone created by Route53 Registrar"
  name    = local.domain
}

resource aws_s3_bucket website {
  acl           = "private"
  bucket        = "www.${local.domain}"
  force_destroy = false
  tags          = local.tags

  website {
    error_document = "error.html"
    index_document = "index.html"
  }
}

resource aws_s3_bucket_policy website {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json
}

resource aws_s3_bucket_public_access_block website {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output bucket_name {
  description = "S3 website bucket name."
  value       = aws_s3_bucket.website.bucket
}

output cloudfront_distribution_id {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.website.id
}
