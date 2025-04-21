locals {
  interconlarp_org_intercode_subdomains = toset([
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x"
  ])
  interconlarp_org_redirect_subdomains = {
    "a.interconlarp.org"    = "A/",
    "b.interconlarp.org"    = "B/",
    "c.interconlarp.org"    = "C/",
    "xiii.interconlarp.org" = "XIII/",
    "xiv.interconlarp.org"  = "XIV/",
    "xv.interconlarp.org"   = "XV/"
  }
}

resource "cloudflare_zone" "interconlarp_org" {
  account = {
    id = "9e36b5cabcd5529d3bd08131b7541c06"
  }
  name = "interconlarp.org"
}

resource "cloudflare_zone_setting" "interconlarp_org_ssl" {
  zone_id    = cloudflare_zone.interconlarp_org.id
  setting_id = "ssl"
  value      = "flexible"
}

resource "cloudflare_zone_setting" "interconlarp_org_always_use_https" {
  zone_id    = cloudflare_zone.interconlarp_org.id
  setting_id = "always_use_https"
  value      = "on"
}

resource "cloudflare_zone_setting" "interconlarp_org_security_header" {
  zone_id    = cloudflare_zone.interconlarp_org.id
  setting_id = "security_header"
  value = [{
    enabled            = true
    include_subdomains = true
    preload            = true
    max_age            = 31536000
  }]
}

resource "aws_s3_bucket" "interconlarp_org" {
  bucket = "interconlarp.org"
}

resource "aws_s3_bucket_acl" "interconlarp_org" {
  bucket = aws_s3_bucket.interconlarp_org.bucket
  acl    = "public-read"
}

resource "aws_s3_bucket_website_configuration" "interconlarp_org" {
  bucket = aws_s3_bucket.interconlarp_org.bucket
  error_document {
    key = "error.html"
  }
  index_document {
    suffix = "index.html"
  }
  routing_rules = jsonencode(
    [
      {
        Condition = {
          KeyPrefixEquals = "policy"
        }
        Redirect = {
          HostName         = "x.interconlarp.org"
          HttpRedirectCode = "302"
          Protocol         = "https"
          ReplaceKeyWith   = "pages/rules"
        }
      },
      {
        Redirect = {
          HostName         = "x.interconlarp.org"
          HttpRedirectCode = "302"
          Protocol         = "https"
          ReplaceKeyWith   = ""
        }
      },
    ]
  )
}

module "interconlarp_org_cloudfront" {
  source = "./modules/cloudfront_with_acm"

  domain_name              = "interconlarp.org"
  alternative_names        = ["www.interconlarp.org"]
  cloudflare_zone          = cloudflare_zone.interconlarp_org
  origin_id                = "S3-interconlarp.org"
  origin_domain_name       = aws_s3_bucket_website_configuration.interconlarp_org.website_endpoint
  add_security_headers_arn = aws_lambda_function.addSecurityHeaders.qualified_arn
}

resource "null_resource" "interconlarp_org_cloudfront_invalidate" {
  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${module.interconlarp_org_cloudfront.cloudfront_distribution.id} --paths '/*'"
  }

  triggers = {
    routing_rules_changed = aws_s3_bucket_website_configuration.interconlarp_org.routing_rules
  }
}

module "interconlarp_org_redirect_subdomain" {
  for_each = local.interconlarp_org_redirect_subdomains

  source = "./modules/cloudflare_apex_redirect"

  cloudflare_zone               = cloudflare_zone.interconlarp_org
  domain_name                   = each.key
  redirect_destination_hostname = "www.interactiveliterature.org"
  redirect_destination_path     = each.value
  redirect_destination_protocol = "https"
  alternative_names             = []
}

resource "cloudflare_dns_record" "interconlarp_org_apex_alias" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "interconlarp.org"
  type    = "CNAME"
  content = module.interconlarp_org_cloudfront.cloudfront_distribution.domain_name
  ttl     = 1
}

resource "cloudflare_dns_record" "interconlarp_org_mx" {
  zone_id  = cloudflare_zone.interconlarp_org.id
  name     = "interconlarp.org"
  type     = "MX"
  content  = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
  ttl      = 1
}

resource "cloudflare_dns_record" "interconlarp_org_forwardemail_verification_txt" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "interconlarp.org"
  type    = "TXT"
  content = "forward-email-site-verification=${local.forwardemail_verification_records_by_domain["interconlarp.org"]}"
  ttl     = 3600
}

resource "cloudflare_dns_record" "interconlarp_org_acme_challenge_cname" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "_acme-challenge"
  type    = "CNAME"
  content = "interconlarp.org.j2o5oe.flydns.net."
  ttl     = 1
}

resource "cloudflare_dns_record" "interconlarp_org_convention_subdomain_cname" {
  for_each = local.interconlarp_org_intercode_subdomains

  zone_id = cloudflare_zone.interconlarp_org.id
  name    = each.value
  type    = "A"
  content = "137.66.59.126"
  ttl     = 1
}

resource "cloudflare_dns_record" "interconlarp_org_convention_subdomain_aaaa" {
  for_each = local.interconlarp_org_intercode_subdomains

  zone_id = cloudflare_zone.interconlarp_org.id
  name    = each.value
  type    = "AAAA"
  content = "2a09:8280:1::4e:bee4"
  ttl     = 1
}

resource "cloudflare_dns_record" "interconlarp_org_convention_subdomain_mx" {
  for_each = local.interconlarp_org_intercode_subdomains

  zone_id  = cloudflare_zone.interconlarp_org.id
  name     = each.value
  type     = "MX"
  content  = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
  ttl      = 1
}

resource "cloudflare_dns_record" "interconlarp_org_convention_subdomain_forwardemail_verification_txt" {
  for_each = local.interconlarp_org_intercode_subdomains

  zone_id = cloudflare_zone.interconlarp_org.id
  name    = each.value
  type    = "TXT"
  content = "forward-email-site-verification=${local.forwardemail_verification_records_by_domain["${each.value}.interconlarp.org"]}"
  ttl     = 3600
}

resource "cloudflare_dns_record" "interconlarp_org_convention_subdomain_events_mx" {
  for_each = local.interconlarp_org_intercode_subdomains

  zone_id  = cloudflare_zone.interconlarp_org.id
  name     = "events.${each.value}"
  type     = "MX"
  content  = "inbound-smtp.us-east-1.amazonaws.com"
  priority = 10
  ttl      = 1
}

resource "cloudflare_dns_record" "interconlarp_org_convention_subdomain_events_forwardemail_verification_txt" {
  for_each = local.interconlarp_org_intercode_subdomains

  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "events.${each.value}"
  type    = "TXT"
  content = "forward-email-site-verification=${local.forwardemail_verification_records_by_domain["events.${each.value}.interconlarp.org"]}"
  ttl     = 3600
}


resource "cloudflare_dns_record" "interconlarp_org_www_cname" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "www"
  type    = "CNAME"
  content = module.interconlarp_org_cloudfront.cloudfront_distribution.domain_name
  ttl     = 1
}

resource "cloudflare_dns_record" "interconlarp_org_spf_record" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "interconlarp.org"
  type    = "TXT"
  content = "v=spf1 include:amazonses.com ~all"
  ttl     = 1
}

resource "cloudflare_dns_record" "interconlarp_org_google_site_verification_record" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "interconlarp.org"
  type    = "TXT"
  content = "google-site-verification=RzGiDCnUV6z9mlwsITO48YkMEx6g3V44fGoD7qMYMDE"
  ttl     = 1
}

resource "cloudflare_dns_record" "interconlarp_org_wildcard_cname" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "*"
  type    = "CNAME"
  content = "intercode.fly.dev"
  ttl     = 1
}

resource "cloudflare_dns_record" "interconlarp_org_furniture_cname" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "furniture"
  type    = "CNAME"
  content = "intercon-furniture.fly.dev"
  ttl     = 1
}

resource "cloudflare_dns_record" "interconlarp_org_security_forwarder_cname" {
  zone_id = cloudflare_zone.interconlarp_org.id
  name    = "security-forwarder"
  type    = "CNAME"
  content = "intercon-security-forwarder.fly.dev"
  ttl     = 1
}
