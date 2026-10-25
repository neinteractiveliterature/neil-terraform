locals {
  unmanaged_sending_domains = toset([
    "aegames.org",
    "beconlarp.com",
    "festivalofthelarps.com",
    "greaterbostonlarpsociety.org",
    "natbudin.com",
    "tapestrieslarp.org"
  ])

  managed_sending_domains = {
    "concentral.net"            = cloudflare_zone.concentral_net.id
    "extraconlarp.org"          = cloudflare_zone.extraconlarp_org.id
    "interactiveliterature.org" = cloudflare_zone.interactiveliterature_org.id
    "interconlarp.org"          = cloudflare_zone.interconlarp_org.id
    "larplibrary.org"           = cloudflare_zone.larplibrary_org.id
    "neilhosting.net"           = cloudflare_zone.neilhosting_net.id
  }
}

resource "aws_ses_domain_identity" "unmanaged_domain" {
  for_each = local.unmanaged_sending_domains

  domain = each.value
}

resource "aws_ses_domain_dkim" "unmanaged_domain" {
  for_each = local.unmanaged_sending_domains

  domain = aws_ses_domain_identity.unmanaged_domain[each.value].domain
}

module "managed_ses_sending_domain" {
  for_each = local.managed_sending_domains

  source = "github.com/neinteractiveliterature/neil-terraform-modules//ses_sending_domain?ref=main"
  zone_id = each.value
}
