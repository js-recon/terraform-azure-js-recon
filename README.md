<h1 align="center">JS Recon — Terraform Azure Module</h1>

<p align="center">
  Provision an Azure Container App Job that runs <a href="https://js-recon.io">JS Recon</a> against any URL.
  Surface exposed endpoints, client-side vulnerabilities, and leaked source maps automatically.
</p>

<p align="center">
  <a href="https://score.getplumber.io/github.com/js-recon/terraform-azure-js-recon">
    <img src="https://score.getplumber.io/github.com/js-recon/terraform-azure-js-recon.svg" alt="Plumber Score">
  </a>
</p>

---

## Quick start

```hcl
module "js_recon" {
  source  = "js-recon/js-recon/azure"
  version = "~> 1.0"

  url = "https://example.com"
}
```

Apply, then trigger a scan:

```bash
az containerapp job start --name js-recon --resource-group js-recon
```

---

## Scanning a localhost app

Override environment variables at job start time:

```bash
az containerapp job start \
  --name js-recon \
  --resource-group js-recon \
  --env-vars JSR_URL=http://localhost:3000 JSR_START_CMD="npm start"
```

The job waits up to 120 seconds for the URL to respond before scanning.

---

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `url` | Yes | — | Target URL to scan |
| `resource_group_name` | No | `js-recon` | Azure resource group name |
| `location` | No | `East US` | Azure region for all resources |
| `js_recon_version` | No | `latest` | JS Recon version (`latest`, `alpha`, `1.3.1-beta.1`, …) |
| `break_on_map_files` | No | `true` | Fail if `.map` source map files are detected |
| `break_on_vulnerabilities` | No | `true` | Fail if findings at or above the threshold are detected |
| `vulnerability_severity` | No | `high` | Minimum severity to fail on: `low`, `medium`, or `high` |
| `output_dir` | No | `js-recon-output` | Directory to save output files inside the container |
| `job_name` | No | `js-recon` | Name prefix for all Azure resources |
| `create_storage_account` | No | `true` | Whether the module creates a Storage Account for artifacts |
| `storage_account_name` | No | _(auto-generated)_ | Explicit Storage Account name (3-24 lowercase alphanumeric) |
| `storage_container_name` | No | `js-recon-output` | Blob container name for artifacts |
| `schedule` | No | `""` | Cron expression for automated scans (e.g. `0 8 * * *`). Empty = manual only. |
| `build_timeout` | No | `30` | Maximum job duration in minutes |
| `tags` | No | `{}` | Tags applied to all Azure resources |

## Outputs

| Name | Description |
|---|---|
| `container_app_job_name` | Name of the Container App Job |
| `container_app_job_id` | Resource ID of the Container App Job |
| `storage_account_name` | Name of the Azure Storage Account |
| `storage_container_name` | Name of the Blob container |
| `managed_identity_client_id` | Client ID of the user-assigned managed identity |
| `resource_group_name` | Name of the resource group |

---

## Output files

JS Recon writes the following files inside the output directory and uploads them to Azure Blob Storage:

| File | Description |
|---|---|
| `analyze.json` | All vulnerability findings |
| `mapped.json` | Parsed bundle structure |
| `mapped-openapi.json` | Extracted HTTP endpoints (OpenAPI format) |
| `endpoints.json` | Client-side routes |
| `strings.json` | Extracted strings, URLs, and secrets |
| `report.html` | Full HTML report |
| `js-recon.db` | SQLite database of all findings |

Artifacts are uploaded to `https://<storage_account>.blob.core.windows.net/<storage_container>/` using azcopy with the managed identity.

---

## Break conditions

### Source maps

```hcl
module "js_recon" {
  source = "js-recon/js-recon/azure"
  url    = "https://example.com"

  break_on_map_files = true # default
}
```

### Vulnerabilities

```hcl
module "js_recon" {
  source = "js-recon/js-recon/azure"
  url    = "https://example.com"

  break_on_vulnerabilities = true
  vulnerability_severity   = "medium"
}
```

---

## Scheduled scans

```hcl
module "js_recon" {
  source = "js-recon/js-recon/azure"
  url    = "https://example.com"

  schedule = "0 8 * * *"
}
```

---

## Triggering a scan manually

```bash
# Start a job execution
az containerapp job start --name js-recon --resource-group js-recon

# Override the target URL at run time
az containerapp job start \
  --name js-recon \
  --resource-group js-recon \
  --env-vars JSR_URL=https://other.example.com
```

---

## Examples

- [`examples/basic/`](examples/basic/) — minimal on-demand scan
- [`examples/scheduled/`](examples/scheduled/) — daily automated scan

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

---

## License

MIT — see [LICENSE](LICENSE).
