resource "aws_ses_domain_identity" "convention_host" {
  domain = "convention.host"
}

resource "aws_ses_domain_dkim" "convention_host" {
  domain = aws_ses_domain_identity.convention_host.domain
}

resource "aws_ses_domain_identity" "interactiveliterature_org" {
  domain = "interactiveliterature.org"
}

resource "aws_ses_domain_dkim" "interactiveliterature_org" {
  domain = aws_ses_domain_identity.interactiveliterature_org.domain
}

resource "aws_ses_domain_identity" "interconlarp_org" {
  domain = "interconlarp.org"
}

resource "aws_ses_domain_dkim" "interconlarp_org" {
  domain = aws_ses_domain_identity.interconlarp_org.domain
}

resource "aws_ses_domain_identity" "larplibrary_org" {
  domain = "larplibrary.org"
}

resource "aws_ses_domain_dkim" "larplibrary_org" {
  domain = aws_ses_domain_identity.larplibrary_org.domain
}

resource "aws_ses_domain_identity" "neilhosting_net" {
  domain = aws_route53_zone.neilhosting_net.name
}

resource "aws_ses_domain_dkim" "neilhosting_net" {
  domain = aws_ses_domain_identity.neilhosting_net.domain
}

resource "aws_route53_record" "neilhosting_net_amazonses" {
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name = "_amazonses.neilhosting.net"
  type = "TXT"
  ttl = 600
  records = [aws_ses_domain_identity.neilhosting_net.verification_token]
}

resource "aws_route53_record" "neilhosting_net_amazonses_dkim" {
  count   = 3
  zone_id = aws_route53_zone.neilhosting_net.zone_id
  name    = "${element(aws_ses_domain_dkim.neilhosting_net.dkim_tokens, count.index)}._domainkey.${aws_ses_domain_dkim.neilhosting_net.domain}"
  type    = "CNAME"
  ttl     = "600"
  records = ["${element(aws_ses_domain_dkim.neilhosting_net.dkim_tokens, count.index)}.dkim.amazonses.com"]
}
