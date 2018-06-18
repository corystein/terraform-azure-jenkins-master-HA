resource "azurerm_availability_set" "avset" {
  name                         = "${var.config["avail_set_name"]}"
  resource_group_name          = "${azurerm_resource_group.res_group.name}"
  location                     = "${azurerm_resource_group.res_group.location}"
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}
