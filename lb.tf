resource "azurerm_public_ip" "jenkins_loadbalancer_publicip" {
  name                = "${var.config["network_public_ipaddress_name"]}"
  resource_group_name = "${azurerm_resource_group.res_group.name}"
  location            = "${azurerm_resource_group.res_group.location}"

  public_ip_address_allocation = "dynamic"

  #public_ip_address_allocation = "static"

  #domain_name_label            = "${var.lb_ip_dns_name}"
}

resource "azurerm_lb" "jenkins_lb" {
  name                = "jenkins_lb"
  resource_group_name = "${azurerm_resource_group.res_group.name}"
  location            = "${azurerm_resource_group.res_group.location}"

  frontend_ip_configuration {
    name                 = "jenkins_lb_frontend"
    public_ip_address_id = "${azurerm_public_ip.jenkins_loadbalancer_publicip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "jenkins_lb_backend" {
  name                = "jenkins_lb_backend"
  resource_group_name = "${azurerm_resource_group.res_group.name}"
  loadbalancer_id     = "${azurerm_lb.jenkins_lb.id}"
}

resource "azurerm_lb_rule" "lb_rule" {
  resource_group_name            = "${azurerm_resource_group.res_group.name}"
  loadbalancer_id                = "${azurerm_lb.jenkins_lb.id}"
  name                           = "LBRule"
  protocol                       = "tcp"
  frontend_port                  = 80
  backend_port                   = 8080
  frontend_ip_configuration_name = "jenkins_lb_frontend"
  enable_floating_ip             = false
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.jenkins_lb_backend.id}"
  idle_timeout_in_minutes        = 5
  probe_id                       = "${azurerm_lb_probe.lb_probe.id}"
  depends_on                     = ["azurerm_lb_probe.lb_probe"]
}

resource "azurerm_lb_probe" "lb_probe" {
  resource_group_name = "${azurerm_resource_group.res_group.name}"
  loadbalancer_id     = "${azurerm_lb.jenkins_lb.id}"
  name                = "tcpProbe"
  protocol            = "tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}
