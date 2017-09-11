variable main_dns_name          { }
variable redirect_dns_names     {
                                  type = "list"
                                }
variable route53_zone_id        { }
variable redirect_protocol      {
                                  default = "http"
                                }

output "main_bucket"        {
                              value = {
                                website_endpoint = "${aws_s3_bucket.main_bucket.website_endpoint}",
                                arn              = "${aws_s3_bucket.main_bucket.arn}",
                              }
                            }
output "redirect_buckets"   {
                              value = {
                                website_endpoints = "${zipmap(aws_s3_bucket.redirect_buckets.*.bucket, aws_s3_bucket.redirect_buckets.*.website_endpoint)}",
                                arn               = "${zipmap(aws_s3_bucket.redirect_buckets.*.bucket, aws_s3_bucket.redirect_buckets.*.arn)}",
                              }
                            }

#--- S3 ----------------------------------------------------------------------
resource "aws_s3_bucket" "main_bucket" {
  bucket = "${var.main_dns_name}"
  website {
    index_document = "index.html"
    error_document = "404.html"
  }
}

resource "aws_s3_bucket" "redirect_buckets" {
  count = "${length(var.redirect_dns_names)}"

  bucket = "${var.redirect_dns_names[count.index]}"
  website {
    redirect_all_requests_to = "${var.redirect_protocol}://${var.main_dns_name}"
  }
}

#--- Route53 -----------------------------------------------------------------
resource "aws_route53_record" "main_dns_entry" {
  name    = "${var.main_dns_name}"
  type    = "A"
  zone_id = "${var.route53_zone_id}"

  alias {
    name = "${aws_s3_bucket.main_bucket.website_domain}"
    zone_id = "${aws_s3_bucket.main_bucket.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "redirect_dns_entries" {
  count = "${length(var.redirect_dns_names)}"

  name    = "${var.redirect_dns_names[count.index]}"
  type    = "A"
  zone_id = "${var.route53_zone_id}"

  alias {
    name = "${element(aws_s3_bucket.redirect_buckets.*.website_domain, count.index)}"
    zone_id = "${element(aws_s3_bucket.redirect_buckets.*.hosted_zone_id, count.index)}"
    evaluate_target_health = false
  }
}
