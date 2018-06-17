resource "azurerm_resource_group" "res_group" {
  name     = "${var.config["resource_group"]}"
  location = "${var.config["location"]}"
}
