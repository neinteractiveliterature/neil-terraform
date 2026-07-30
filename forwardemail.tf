module "forwardemail_receiving" {
  source     = "github.com/neinteractiveliterature/intercode//terraform/modules/forwardemail_receiving?ref=main&depth=1"
  api_key    = local.secrets["forwardemail_api_key"]
  page_count = 2
  ssm_name   = "intercode_production"
}
