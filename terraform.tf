terraform {
  backend s3 {
    bucket = "brutalismbot"
    key    = "terraform/brutalismbot.com.tf"
    region = "us-east-1"
  }
}

provider aws {
  access_key = "${var.aws_access_key_id}"
  profile    = "${var.aws_profile}"
  region     = "${var.aws_region}"
  secret_key = "${var.aws_secret_access_key}"
  version    = "~> 2.0"
}

locals {
  tags = {
    App     = "brutalismbot"
    Name    = "${var.domain_name}"
    Release = "${var.release}"
    Repo    = "${var.repo}"
  }
}

data aws_iam_policy_document website {
  statement {
    sid       = "1"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::www.${var.domain_name}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.website.iam_arn}"]
    }
  }
}

resource aws_acm_certificate cert {
  domain_name       = "${var.domain_name}"
  tags              = "${local.tags}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource aws_acm_certificate_validation cert {
  certificate_arn         = "${aws_acm_certificate.cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert.fqdn}"]
}

resource aws_cloudfront_distribution website {
  aliases             = ["${var.domain_name}", "www.${var.domain_name}"]
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
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    default_ttl            = 86400
    max_ttl                = 31536000
    min_ttl                = 0
    target_origin_id       = "${aws_s3_bucket.website.bucket}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  origin {
    domain_name = "${aws_s3_bucket.website.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.website.bucket}"

    s3_origin_config {
      origin_access_identity = "${aws_cloudfront_origin_access_identity.website.cloudfront_access_identity_path}"
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = "${aws_acm_certificate_validation.cert.certificate_arn}"
    minimum_protocol_version = "TLSv1.1_2016"
    ssl_support_method       = "sni-only"
  }
}

resource aws_cloudfront_origin_access_identity website {
  comment = "access-identity-www.${var.domain_name}.s3.amazonaws.com"
}

resource aws_route53_record a {
  name    = "${var.domain_name}"
  type    = "A"
  zone_id = "${aws_route53_zone.website.id}"

  alias {
    evaluate_target_health = false
    name                   = "${aws_cloudfront_distribution.website.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.website.hosted_zone_id}"
  }
}

resource aws_route53_record aaaa {
  name    = "${var.domain_name}"
  type    = "AAAA"
  zone_id = "${aws_route53_zone.website.id}"

  alias {
    evaluate_target_health = false
    name                   = "${aws_cloudfront_distribution.website.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.website.hosted_zone_id}"
  }
}

resource aws_route53_record cert {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 300
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${aws_route53_zone.website.id}"
}

resource aws_route53_record www_a {
  name    = "www.${var.domain_name}"
  type    = "A"
  zone_id = "${aws_route53_zone.website.id}"

  alias {
    evaluate_target_health = false
    name                   = "${aws_cloudfront_distribution.website.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.website.hosted_zone_id}"
  }
}

resource aws_route53_record www_aaaa {
  name    = "www.${var.domain_name}"
  type    = "AAAA"
  zone_id = "${aws_route53_zone.website.id}"

  alias {
    evaluate_target_health = false
    name                   = "${aws_cloudfront_distribution.website.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.website.hosted_zone_id}"
  }
}

resource aws_route53_zone website {
  comment = "HostedZone created by Route53 Registrar"
  name    = "${var.domain_name}"
}

resource aws_s3_bucket website {
  acl           = "private"
  bucket        = "www.${var.domain_name}"
  force_destroy = false
  policy        = "${data.aws_iam_policy_document.website.json}"
  tags          = "${local.tags}"

  website {
    error_document = "error.html"
    index_document = "index.html"
  }
}

variable aws_access_key_id {
  description = "AWS Access Key ID."
  default     = ""
}

variable aws_secret_access_key {
  description = "AWS Secret Access Key."
  default     = ""
}

variable aws_profile {
  description = "AWS Profile."
  default     = ""
}

variable aws_region {
  description = "AWS Region."
  default     = "us-east-1"
}

variable domain_name {
  description = "Website domain name."
  default     = "brutalismbot.com"
}

variable release {
  description = "Release tag."
}

variable repo {
  description = "Project repository."
  default     = "https://github.com/brutalismbot/brutalismbot.com"
}

output bucket_name {
  description = "S3 website bucket name."
  value       = "${aws_s3_bucket.website.bucket}"
}

output cloudfront_distribution_id {
  description = "CloudFront distribution ID."
  value       = "${aws_cloudfront_distribution.website.id}"
}
