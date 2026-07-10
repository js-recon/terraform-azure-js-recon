output "container_app_job_name" {
  description = "Name of the Container App Job"
  value       = azurerm_container_app_job.js_recon.name
}

output "container_app_job_id" {
  description = "Resource ID of the Container App Job"
  value       = azurerm_container_app_job.js_recon.id
}

output "storage_account_name" {
  description = "Name of the Azure Storage Account where JS Recon artifacts are stored"
  value       = var.create_storage_account ? azurerm_storage_account.artifacts[0].name : var.storage_account_name
}

output "storage_container_name" {
  description = "Name of the Blob container where artifacts are uploaded"
  value       = var.storage_container_name
}

output "managed_identity_client_id" {
  description = "Client ID of the user-assigned managed identity assigned to the Container App Job"
  value       = azurerm_user_assigned_identity.js_recon.client_id
}

output "resource_group_name" {
  description = "Name of the resource group containing all module resources"
  value       = azurerm_resource_group.js_recon.name
}
