module "forwardemail_receiving" {
  source     = "github.com/neinteractiveliterature/intercode//terraform/modules/forwardemail_receiving?ref=main&depth=1"
  api_key    = var.forwardemail_api_key
  page_count = 2
}
