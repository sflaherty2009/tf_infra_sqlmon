resource "azurerm_resource_group" "rg" {
  name     = "AZ-RG-${upper(lookup(var.penv,terraform.workspace))}-sqlmon"
  location = "${var.location}"
}

resource "azurerm_management_lock" "prod_lock" {
  name       = "DoNotDelete"
  scope      = "${azurerm_resource_group.rg.id}"
  lock_level = "CanNotDelete"
  notes      = "Implemented as part of DVO-3231"
}
