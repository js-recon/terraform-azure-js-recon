provider "azurerm" {
  features {}
}

module "js_recon" {
  source = "../../"

  url = "https://example.com"
}

output "container_app_job_name" {
  value = module.js_recon.container_app_job_name
}

output "storage_account_name" {
  value = module.js_recon.storage_account_name
}
