provider archive {
  version = "~> 1.2"
}

provider aws {
  access_key = "${var.aws_access_key_id}"
  profile    = "${var.aws_profile}"
  region     = "${var.aws_region}"
  secret_key = "${var.aws_secret_access_key}"
  version    = "~> 2.4"
}

locals {
  html = ["error", "index", "success"]

  tags {
    App     = "brutalismbot"
    Name    = "brutalismbot.com"
    Release = "${var.release}"
    Repo    = "${var.repo}"
  }
}

resource aws_acm_certificate cert {
  domain_name       = "brutalismbot.com"
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
  aliases             = ["brutalismbot.com", "www.brutalismbot.com"]
  default_root_object = "index.html"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100"

  custom_error_response {
    error_caching_min_ttl = 300
    error_code            = 404
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

resource aws_route53_record cert {
  name    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_name}"
  records = ["${aws_acm_certificate.cert.domain_validation_options.0.resource_record_value}"]
  ttl     = 300
  type    = "${aws_acm_certificate.cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${aws_route53_zone.website.id}"
}

resource aws_route53_zone website {
  comment = "HostedZone created by Route53 Registrar"
  name    = "brutalismbot.com"
}

resource aws_s3_bucket website {
  acl           = "public-read"
  bucket        = "brutalismbot.com"
  force_destroy = false
}

resource aws_s3_bucket_object html {
  count        = "${length(local.html)}"
  acl          = "public-read"
  bucket       = "${aws_s3_bucket.website.bucket}"
  content      = "${file("brutalismbot.com/${element(local.html, count.index)}.html")}"
  content_type = "text/html"
  etag         = "${filemd5("brutalismbot.com/${element(local.html, count.index)}.html")}"
  key          = "${element(local.html, count.index)}.html"
  tags         = "${local.tags}"
}

resource aws_s3_bucket_object png {
  acl          = "public-read"
  bucket       = "${aws_s3_bucket.website.bucket}"
  content_type = "image/png"
  etag         = "${filemd5("brutalismbot.com/background.png")}"
  key          = "background.png"
  source       = "brutalismbot.com/background.png"
  tags         = "${local.tags}"
}
