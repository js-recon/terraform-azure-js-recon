locals {
  storage_account_name = var.storage_account_name != "" ? var.storage_account_name : "jsrecon${random_string.storage_suffix[0].result}"
}

resource "random_string" "storage_suffix" {
  count   = var.create_storage_account && var.storage_account_name == "" ? 1 : 0
  length  = 8
  special = false
  upper   = false
  numeric = true
}

# ─── Resource group ───────────────────────────────────────────────────────────

resource "azurerm_resource_group" "js_recon" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ─── Managed identity ─────────────────────────────────────────────────────────

resource "azurerm_user_assigned_identity" "js_recon" {
  name                = var.job_name
  resource_group_name = azurerm_resource_group.js_recon.name
  location            = azurerm_resource_group.js_recon.location
  tags                = var.tags
}

# ─── Azure Storage for artifacts ──────────────────────────────────────────────

resource "azurerm_storage_account" "artifacts" {
  count                    = var.create_storage_account ? 1 : 0
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.js_recon.name
  location                 = azurerm_resource_group.js_recon.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_storage_container" "artifacts" {
  count                 = var.create_storage_account ? 1 : 0
  name                  = var.storage_container_name
  storage_account_id    = azurerm_storage_account.artifacts[0].id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "storage_blob_contributor" {
  count                = var.create_storage_account ? 1 : 0
  scope                = azurerm_storage_account.artifacts[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.js_recon.principal_id
}

# ─── Container App Environment ────────────────────────────────────────────────

resource "azurerm_container_app_environment" "js_recon" {
  name                = var.job_name
  resource_group_name = azurerm_resource_group.js_recon.name
  location            = azurerm_resource_group.js_recon.location
  tags                = var.tags
}

# ─── Container App Job ────────────────────────────────────────────────────────

resource "azurerm_container_app_job" "js_recon" {
  name                         = var.job_name
  resource_group_name          = azurerm_resource_group.js_recon.name
  location                     = azurerm_resource_group.js_recon.location
  container_app_environment_id = azurerm_container_app_environment.js_recon.id

  replica_timeout_in_seconds = var.build_timeout * 60
  replica_retry_limit        = 0

  tags = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.js_recon.id]
  }

  dynamic "manual_trigger_config" {
    for_each = var.schedule == "" ? [1] : []
    content {
      parallelism              = 1
      replica_completion_count = 1
    }
  }

  dynamic "schedule_trigger_config" {
    for_each = var.schedule != "" ? [1] : []
    content {
      cron_expression          = var.schedule
      parallelism              = 1
      replica_completion_count = 1
    }
  }

  template {
    container {
      name   = "js-recon"
      image  = "ghcr.io/puppeteer/puppeteer:24.43.1"
      cpu    = 2.0
      memory = "4Gi"

      command = ["/bin/bash", "-c", <<-SCRIPT
        set -e
        npm config set prefix /home/pptruser/.npm-global
        export PATH="/home/pptruser/.npm-global/bin:$PATH"

        echo "[js-recon] Installing @js-recon/js-recon@$JSR_VERSION..."
        npm install -g "@js-recon/js-recon@$JSR_VERSION"
        INSTALLED_VERSION=$(js-recon --version 2>/dev/null || echo "unknown")
        echo "[js-recon] Installed version: $INSTALLED_VERSION"

        if [ -n "$JSR_START_CMD" ]; then
          echo "[js-recon] Starting app with: $JSR_START_CMD"
          cd "$${JSR_WORKING_DIR:-.}"
          eval "$JSR_START_CMD" &
          cd -
          echo "[js-recon] Waiting for $JSR_URL to be ready..."
          curl --silent --output /dev/null --retry 30 --retry-connrefused --retry-delay 2 --retry-max-time 120 "$JSR_URL" || {
            echo "[js-recon] ERROR: Timed out waiting for $JSR_URL"
            exit 1
          }
          echo "[js-recon] App is ready."
        fi

        echo "[js-recon] Running js-recon against $JSR_URL..."
        js-recon run -u "$JSR_URL" -o "$JSR_OUTPUT_DIR" --no-sandbox -y -k || {
          echo "[js-recon] ERROR: js-recon run failed."
          exit 1
        }
        echo "[js-recon] Scan complete."

        HOST_DIR=$(echo "$JSR_URL" | sed 's|https\?://||' | sed 's|[/?].*||' | tr ':' '_')
        mkdir -p "$JSR_OUTPUT_DIR/$HOST_DIR"
        for f in analyze.json mapped.json mapped-openapi.json endpoints.json strings.json report.html report.db js-recon.db; do
          [ -f "$f" ] && mv "$f" "$JSR_OUTPUT_DIR/$HOST_DIR/" 2>/dev/null || true
        done

        MAP_FILES=$(find "$JSR_OUTPUT_DIR" -name "*.map" 2>/dev/null | head -50)
        if [ -n "$MAP_FILES" ]; then
          echo "[js-recon] Source map files detected:"
          echo "$MAP_FILES"
          if [ "$JSR_BREAK_ON_MAP" = "true" ]; then
            echo "[js-recon] ERROR: Source map files are publicly accessible. Set break_on_map_files = false to suppress."
            exit 1
          fi
        fi

        ANALYZE_JSON=$(find "$JSR_OUTPUT_DIR" -name "analyze.json" 2>/dev/null | head -1)
        if [ -n "$ANALYZE_JSON" ] && [ "$JSR_BREAK_ON_VULNS" = "true" ]; then
          node -e "
        const fs = require('fs');
        const RANK = {info: 0, low: 1, medium: 2, high: 3};
        let findings = [];
        try { findings = JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); } catch {
          console.log('[js-recon] analyze.json is empty or invalid. Skipping.');
          process.exit(0);
        }
        if (!Array.isArray(findings) || findings.length === 0) {
          console.log('[js-recon] No findings in analyze.json.');
          process.exit(0);
        }
        const severity = process.argv[2];
        const threshold = RANK[severity] ?? 3;
        const matched = findings.filter(f => (RANK[f.severity?.toLowerCase()] ?? -1) >= threshold);
        if (matched.length === 0) {
          console.log('[js-recon] No findings at or above severity \"' + severity + '\".');
          process.exit(0);
        }
        console.log('[js-recon] ' + matched.length + ' finding(s) at or above severity \"' + severity + '\":\n');
        console.log('Rule'.padEnd(40) + ' ' + 'Severity'.padEnd(10) + ' Location');
        console.log('-'.repeat(80));
        for (const f of matched) {
          const rule = (f.ruleName || f.ruleId || 'unknown').substring(0, 39).padEnd(40);
          const sev  = (f.severity || '?').padEnd(10);
          const loc  = f.findingLocation || '';
          console.log(rule + ' ' + sev + ' ' + loc);
        }
        console.log('\n[js-recon] ERROR: ' + matched.length + ' vulnerability/vulnerabilities at severity \"' + severity + '\" or above.');
        process.exit(matched.length > 255 ? 255 : matched.length);
          " "$ANALYZE_JSON" "$JSR_SEVERITY" || exit 1
        fi

        if [ -n "$JSR_STORAGE_ACCOUNT" ]; then
          echo "[js-recon] Uploading artifacts to Azure Blob Storage..."
          curl -L https://aka.ms/downloadazcopy-v10-linux -o /tmp/azcopy_v10.tar.gz
          tar -xzf /tmp/azcopy_v10.tar.gz -C /tmp
          AZCOPY=$(find /tmp -name azcopy -type f | head -1)
          chmod +x "$AZCOPY"
          "$AZCOPY" login --identity --identity-client-id "$JSR_IDENTITY_CLIENT_ID"
          "$AZCOPY" copy "$JSR_OUTPUT_DIR/*" "https://$JSR_STORAGE_ACCOUNT.blob.core.windows.net/$JSR_STORAGE_CONTAINER/" --recursive=true
          echo "[js-recon] Artifacts uploaded."
        fi
      SCRIPT
      ]

      env {
        name  = "JSR_URL"
        value = var.url
      }
      env {
        name  = "JSR_VERSION"
        value = var.js_recon_version
      }
      env {
        name  = "JSR_BREAK_ON_MAP"
        value = tostring(var.break_on_map_files)
      }
      env {
        name  = "JSR_BREAK_ON_VULNS"
        value = tostring(var.break_on_vulnerabilities)
      }
      env {
        name  = "JSR_SEVERITY"
        value = var.vulnerability_severity
      }
      env {
        name  = "JSR_OUTPUT_DIR"
        value = var.output_dir
      }
      env {
        name  = "JSR_STORAGE_ACCOUNT"
        value = var.create_storage_account ? azurerm_storage_account.artifacts[0].name : var.storage_account_name
      }
      env {
        name  = "JSR_STORAGE_CONTAINER"
        value = var.storage_container_name
      }
      env {
        name  = "JSR_IDENTITY_CLIENT_ID"
        value = azurerm_user_assigned_identity.js_recon.client_id
      }
      env {
        name  = "PUPPETEER_SKIP_DOWNLOAD"
        value = "true"
      }
      env {
        name  = "IS_DOCKER"
        value = "true"
      }
      env {
        name  = "NODE_OPTIONS"
        value = "--max-http-header-size=99999999"
      }
      env {
        name  = "PUPPETEER_CACHE_DIR"
        value = "/home/pptruser/.cache/puppeteer"
      }
    }
  }
}
