terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-logicapp-sb-apim-demo"
  location = "uksouth"
}
resource "azurerm_logic_app_workflow" "logic_app" {
  name                = "logicapp-sb-apim-demo"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  workflow_parameters = {
    "$connections" = jsonencode({
      defaultValue = {}
      type         = "Object"
    })
  }

  parameters = {
    "$connections" = jsonencode({
      servicebus = {
        connectionId   = azurerm_api_connection.servicebus.id
        connectionName = azurerm_api_connection.servicebus.name
        id             = data.azurerm_managed_api.servicebus.id
      }
    })
  }

}
# Service Bus Namespace
resource "azurerm_servicebus_namespace" "sb_ns" {
  name                = "logicapp-sb-apim-demo-ns"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
}

# Service Bus Topic
resource "azurerm_servicebus_topic" "sb_topic" {
  name         = "clienttopic"
  namespace_id = azurerm_servicebus_namespace.sb_ns.id
}

# Service Bus Subscription
resource "azurerm_servicebus_subscription" "sb_subscription" {
  name                                 = "functionapp-subscription"
  topic_id                             = azurerm_servicebus_topic.sb_topic.id
  max_delivery_count                   = 10
  lock_duration                        = "PT30S"
  dead_lettering_on_message_expiration = true
}


# The workflow definition
resource "azurerm_logic_app_trigger_http_request" "http_trigger" {
  name         = "httpRequestTrigger"
  logic_app_id = azurerm_logic_app_workflow.logic_app.id

  schema = jsonencode({
    type = "object"
    properties = {
      message = {
        type = "string"
      }
    }
  })
}

resource "azurerm_logic_app_action_custom" "send_to_service_bus" {
  name         = "send_message_to_service_bus"
  logic_app_id = azurerm_logic_app_workflow.logic_app.id

  body = jsonencode({
    type = "ApiConnection"
    inputs = {
      host = {
        connection = {
          name = "@parameters('$connections')['servicebus']['connectionId']"
        }
      }
      method = "post"
      path   = "/clienttopic/messages"
      body = {
        ContentData = "@{base64(triggerBody())}"
      }
    }
  })

  depends_on = [
    azurerm_logic_app_trigger_http_request.http_trigger,
    azurerm_api_connection.servicebus
  ]
}




resource "azurerm_api_connection" "servicebus" {
  name                = "servicebus-connection"
  resource_group_name = azurerm_resource_group.rg.name
  managed_api_id      = data.azurerm_managed_api.servicebus.id
  display_name        = "Service Bus Connection"

  parameter_values = {
    connectionString = azurerm_servicebus_namespace.sb_ns.default_primary_connection_string
  }
}

data "azurerm_managed_api" "servicebus" {
  name     = "servicebus"
  location = azurerm_resource_group.rg.location
}


resource "azurerm_logic_app_workflow" "blob_email_logicapp" {
  name                = "logicapp-blob-email"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  workflow_parameters = {
    "$connections" = jsonencode({
      defaultValue = {}
      type         = "Object"
    })
  }
}
