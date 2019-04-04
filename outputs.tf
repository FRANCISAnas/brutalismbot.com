output acm_certificate_arn {
  description = "ACM Certificate ARN."
  value       = "${aws_acm_certificate.cert.arn}"
}

output route53_zone_id {
  description = "Route53 Zone ID."
  value       = "${aws_route53_zone.website.id}"
}
