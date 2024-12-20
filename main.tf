terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.12.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "80c83ed5-d3c5-499c-b352-5ca63ed36892"
  features {
  }
}

resource "random_integer" "random" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "dbalkanskirg" {
  name     = "${var.resource_group_name}${random_integer.random.result}"
  location = var.resource_group_location
}

resource "azurerm_service_plan" "dbalkanskisp" {
  name                = "${var.app_service_plan_name}-${random_integer.random.result}"
  resource_group_name = azurerm_resource_group.dbalkanskirg.name
  location            = azurerm_resource_group.dbalkanskirg.location
  os_type             = "Linux"
  sku_name            = "F1"
}

resource "azurerm_linux_web_app" "dbalkanskiwa" {
  name                = "${var.app_service_name}-${random_integer.random.result}"
  resource_group_name = azurerm_resource_group.dbalkanskirg.name
  location            = azurerm_resource_group.dbalkanskirg.location
  service_plan_id     = azurerm_service_plan.dbalkanskisp.id

  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
    always_on = false
  }
  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Data Source=tcp:${azurerm_mssql_server.dbalkanskiams.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.dbalkanskiamd.name};User ID=${azurerm_mssql_server.dbalkanskiams.administrator_login};Password=${azurerm_mssql_server.dbalkanskiams.administrator_login_password};Trusted_Connection=False; MultipleActiveResultSets=True;"
  }
}

resource "azurerm_mssql_server" "dbalkanskiams" {
  name                         = var.sql_service_name
  resource_group_name          = azurerm_resource_group.dbalkanskirg.name
  location                     = azurerm_resource_group.dbalkanskirg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
}

resource "azurerm_mssql_database" "dbalkanskiamd" {
  name           = var.sql_database_name
  server_id      = azurerm_mssql_server.dbalkanskiams.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 2
  zone_redundant = false
  sku_name       = "S0"
}

resource "azurerm_mssql_firewall_rule" "dbalkanskifirewall" {
  name             = var.firewall_rule_name
  server_id        = azurerm_mssql_server.dbalkanskiams.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_app_service_source_control" "github" {
  app_id                 = azurerm_linux_web_app.dbalkanskiwa.id
  repo_url               = var.repo_URL
  branch                 = "main"
  use_manual_integration = true
}

