data "http" "forwardemail_domains" {
  # increase this if we go past 100 domains
  count = 2

  url = "https://api.forwardemail.net/v1/domains?page=${count.index + 1}"

  request_headers = {
    Authorization = "Basic ${base64encode("${var.forwardemail_api_key}:")}"
  }
}

locals {
  forwardemail_domains_decoded = [for page in data.http.forwardemail_domains : jsondecode(page.body)]
  forwardemail_domains         = concat(local.forwardemail_domains_decoded...)

  forwardemail_verification_records_by_domain = {
    for domain in local.forwardemail_domains :
    domain["name"] => domain["verification_record"]
  }
}
