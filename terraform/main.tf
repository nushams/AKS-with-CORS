provider "azurerm" {
  features {}
  
  subscription_id = "245ce031-cd70-4369-9fe3-b22d7fb8a0f0"
}

resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "example" {
  name                = "AKSVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "example" {
  name                 = "AKSSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_kubernetes_cluster" "example" {
  name                = "AKS-Cluster"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  dns_prefix          = "aks"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = "testing"
  }
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.example.kube_config
  sensitive = true
}

output "kube_config_raw" {
  value = azurerm_kubernetes_cluster.example.kube_config_raw
  sensitive = true
}