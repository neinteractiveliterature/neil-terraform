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

moved {
  from = module.concentral_net_ses_sending_domain
  to   = module.managed_ses_sending_domain["concentral.net"]
}

moved {
  from = module.extraconlarp_org_ses_sending_domain
  to   = module.managed_ses_sending_domain["extraconlarp.org"]
}

moved {
  from = module.interactiveliterature_org_ses_sending_domain
  to   = module.managed_ses_sending_domain["interactiveliterature.org"]
}

moved {
  from = module.larplibrary_org_ses_sending_domain
  to   = module.managed_ses_sending_domain["larplibrary.org"]
}

moved {
  from = module.neilhosting_net_ses_sending_domain
  to   = module.managed_ses_sending_domain["neilhosting.net"]
}

moved {
  from = aws_ses_domain_dkim.unmanaged_domain["interconlarp.org"]
  to   = module.managed_ses_sending_domain["interconlarp.org"].aws_ses_domain_dkim.domain_dkim
}

moved {
  from = aws_ses_domain_identity.unmanaged_domain["interconlarp.org"]
  to   = module.managed_ses_sending_domain["interconlarp.org"].aws_ses_domain_identity.domain_identity
}

moved {
  from = cloudflare_record.interconlarp_org_amazonses_dkim_record
  to   = module.managed_ses_sending_domain["interconlarp.org"].cloudflare_record.amazonses_verification_record
}
