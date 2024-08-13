output "aks_cluster_name" {
  description = "The name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.example.name
}

output "resource_group_name" {
  description = "The name of the resource group."
  value       = azurerm_resource_group.example.name
}

output "location" {
  description = "The Azure location where resources are created."
  value       = azurerm_resource_group.example.location
}