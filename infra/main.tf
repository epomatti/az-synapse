terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.111.0"
    }
  }
}

data "azuread_client_config" "current" {}

locals {
  client_object_id = data.azuread_client_config.current.object_id
  client_tenant_id = data.azuread_client_config.current.tenant_id
}

### Group ###
resource "azurerm_resource_group" "default" {
  name     = "rg${var.workload}"
  location = var.location
}

### Data Lake ###
resource "azurerm_storage_account" "lake" {
  name                     = "dls${var.workload}"
  resource_group_name      = azurerm_resource_group.default.name
  location                 = azurerm_resource_group.default.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
}

resource "azurerm_role_assignment" "adlsv2" {
  scope                = azurerm_storage_account.lake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_client_config.current.object_id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "default" {
  name               = "dls${var.workload}"
  storage_account_id = azurerm_storage_account.lake.id

  depends_on = [
    azurerm_role_assignment.adlsv2
  ]
}

# Synapse
resource "azurerm_synapse_workspace" "w001" {
  name                                 = "synw${var.workload}"
  resource_group_name                  = azurerm_resource_group.default.name
  location                             = azurerm_resource_group.default.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.default.id
  sql_administrator_login              = "sqladmin"
  sql_administrator_login_password     = var.synapse_password

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_synapse_workspace_aad_admin" "w001" {
  synapse_workspace_id = azurerm_synapse_workspace.w001.id
  login                = "AzureAD Admin"
  object_id            = local.client_object_id
  tenant_id            = local.client_tenant_id
}

# For development only
# Poduction scenarios: https://techcommunity.microsoft.com/t5/azure-synapse-analytics-blog/disabling-public-network-access-in-synapse/ba-p/3692197
resource "azurerm_synapse_firewall_rule" "allow_all" {
  name                 = "AllowAll"
  synapse_workspace_id = azurerm_synapse_workspace.w001.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "255.255.255.255"
}

resource "azurerm_synapse_sql_pool" "test1" {
  name                 = "syndp${var.workload}"
  synapse_workspace_id = azurerm_synapse_workspace.w001.id
  sku_name             = "DW100c"
  create_mode          = "Default"
}
