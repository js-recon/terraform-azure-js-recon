# Changelog

## 1.0.0 — 2026-07-10

Initial release.

- Azure Container App Job that runs JS Recon against any URL
- User-assigned managed identity for authentication
- Optional Azure Storage Account for artifact storage
- Optional cron schedule via Container App Job schedule trigger
- Inputs mirroring the GitHub Action and GitLab CI component: `url`, `js_recon_version`, `break_on_map_files`, `break_on_vulnerabilities`, `vulnerability_severity`, `output_dir`
- Outputs: `container_app_job_name`, `container_app_job_id`, `storage_account_name`, `storage_container_name`, `managed_identity_client_id`, `resource_group_name`
- Examples: `basic/` (on-demand) and `scheduled/` (daily cron)
