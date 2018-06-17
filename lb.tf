resource "azurerm_public_ip" "jenkins_loadbalancer_publicip" {
  name                = "${var.config["network_public_ipaddress_name"]}"
  resource_group_name = "${azurerm_resource_group.res_group.name}"
  location            = "${azurerm_resource_group.res_group.location}"

  public_ip_address_allocation = "static"
}
