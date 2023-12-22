terraform {
  backend "azurerm" {
    storage_account_name = "terraformlock"
    container_name       = "environments"
    resource_group_name  = "dvo_terraform"
    key                  = "sql_mon/terraform.tfstate"
  }
  required_providers {
      azurerm = {
        subscription_id = "${lookup(var.subscription_id,terraform.workspace)}"
      }
  }
}
