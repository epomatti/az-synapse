terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.56.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
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

data "azuread_client_config" "current" {}

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
