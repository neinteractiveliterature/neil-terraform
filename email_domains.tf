resource "aws_ses_domain_identity" "concentral_net" {
  domain = "concentral.net"
}

resource "aws_ses_domain_dkim" "concentral_net" {
  domain = aws_ses_domain_identity.concentral_net.domain
}

resource "aws_ses_domain_identity" "convention_host" {
  domain = "convention.host"
}

resource "aws_ses_domain_dkim" "convention_host" {
  domain = aws_ses_domain_identity.convention_host.domain
}

resource "aws_ses_domain_identity" "festivalofthelarps_com" {
  domain = "festivalofthelarps.com"
}

resource "aws_ses_domain_dkim" "festivalofthelarps_com" {
  domain = aws_ses_domain_identity.festivalofthelarps_com.domain
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

module "larplibrary_org_ses_sending_domain" {
  source = "./modules/ses_sending_domain"
  route53_zone = aws_route53_zone.larplibrary_org
}

resource "aws_ses_domain_identity" "natbudin_com" {
  domain = "natbudin.com"
}

resource "aws_ses_domain_dkim" "natbudin_com" {
  domain = aws_ses_domain_identity.natbudin_com.domain
}

module "neilhosting_net_ses_sending_domain" {
  source = "./modules/ses_sending_domain"
  route53_zone = aws_route53_zone.neilhosting_net
}
