resource "azurerm_virtual_network" "vnet" {
  name                = "${var.config["vnet_name"]}"
  address_space       = ["${var.config["vnet_address_range"]}"]
  resource_group_name = "${azurerm_resource_group.res_group.name}"
  location            = "${azurerm_resource_group.res_group.location}"
}

resource "azurerm_subnet" "subnet1" {
  name                 = "${var.config["subnet_name"]}"
  resource_group_name  = "${azurerm_resource_group.res_group.name}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "${var.config["subnet_address_range"]}"
}
