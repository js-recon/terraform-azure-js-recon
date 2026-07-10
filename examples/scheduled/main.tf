provider "azurerm" {
  features {}
}

module "js_recon" {
  source = "../../"

  url      = "https://example.com"
  schedule = "0 8 * * *"

  break_on_map_files       = true
  break_on_vulnerabilities = true
  vulnerability_severity   = "high"

  tags = {
    Team = "security"
  }
}

output "container_app_job_name" {
  value = module.js_recon.container_app_job_name
}

output "storage_account_name" {
  value = module.js_recon.storage_account_name
}
