terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.110.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false #some app insights stays otherwise
    }
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "cnewclientfunction-rg"
  location = "uksouth"

  tags = {
    environment = "dev"

  }
}

resource "azurerm_storage_account" "func_storage" {
  name                     = "newclientfuncstorageacc"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "dev"

  }
}

resource "azurerm_service_plan" "func_consumption_plan" {
  name                = "adnan-demotfconsumptionplan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "Y1" #changed to consumption plan

  tags = {
    environment = "dev"

  }
}

resource "azurerm_linux_function_app" "func_app" {
  name                = "newclientfunction"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  storage_account_name       = azurerm_storage_account.func_storage.name
  storage_account_access_key = azurerm_storage_account.func_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.func_consumption_plan.id
  app_settings = {
    "ServiceBusConnection" = "" #update it later
  }
  site_config {
    application_stack {
      python_version = "3.11"
    }

    application_insights_connection_string = azurerm_application_insights.insights.connection_string
    application_insights_key               = azurerm_application_insights.insights.instrumentation_key
  }

  tags = {
    environment = "dev"

  }
}

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "newclientfunctionworkspace"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    environment = "dev"

  }
}

resource "azurerm_application_insights" "insights" {
  name                = "newclientfunctionappinsights"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.logs.id
  application_type    = "web"

  tags = {
    environment = "dev"

  }
}
