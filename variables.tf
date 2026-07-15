variable "resource_group_name" {
  description = "Name of the Azure resource group in which all resources are created"
  type        = string
  default     = "js-recon"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "East US"
}

variable "url" {
  description = "Target URL to scan (e.g. https://example.com or http://localhost:3000)"
  type        = string
}

variable "js_recon_version" {
  description = "JS Recon version to install — passed to npm install -g @js-recon/js-recon@<version> (e.g. latest, alpha, 1.3.1-beta.1)"
  type        = string
  default     = "latest"
}

variable "break_on_map_files" {
  description = "Fail the job if .map source map files are detected in the output"
  type        = bool
  default     = true
}

variable "break_on_vulnerabilities" {
  description = "Fail the job if vulnerabilities at or above the configured severity are detected"
  type        = bool
  default     = true
}

variable "vulnerability_severity" {
  description = "Minimum severity to fail on: low, medium, or high"
  type        = string
  default     = "high"

  validation {
    condition     = contains(["low", "medium", "high"], var.vulnerability_severity)
    error_message = "vulnerability_severity must be one of: low, medium, high"
  }
}

variable "output_dir" {
  description = "Directory inside the container where JS Recon output files are saved"
  type        = string
  default     = "js-recon-output"
}

variable "job_name" {
  description = "Name for the Container App Job and prefix for all other resources"
  type        = string
  default     = "js-recon"
}

variable "create_storage_account" {
  description = "Whether to create an Azure Storage Account for storing JS Recon output artifacts"
  type        = bool
  default     = true
}

variable "storage_account_name" {
  description = "Name for the Azure Storage Account. Auto-generated if empty (3-24 lowercase alphanumeric chars, globally unique)"
  type        = string
  default     = ""
}

variable "storage_container_name" {
  description = "Name of the Blob container inside the storage account where artifacts are uploaded"
  type        = string
  default     = "js-recon-output"
}

variable "schedule" {
  description = "Cron expression for automated scans (e.g. 0 8 * * *). Leave empty to disable scheduling."
  type        = string
  default     = ""
}

variable "build_timeout" {
  description = "Maximum duration in minutes for a single scan job"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all Azure resources created by this module"
  type        = map(string)
  default     = {}
}
