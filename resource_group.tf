resource "random_uuid" "lock" { }

resource "azurerm_resource_group" "rg" {
  name     = "AZ-RG-${upper(lookup(var.penv,terraform.workspace))}-sqlmon"
  location = "${var.location}"
}

resource "azurerm_management_lock" "lock" {
  name       = "${azurerm_resource_group.rg.name}_lock_${substr(random_uuid.lock.result, -3, -1)}"
  scope      = "${azurerm_resource_group.rg.id}"
  lock_level = "CanNotDelete"
  notes      = "Implemented as part of DVO-3231"
}
