# Providers

terraform {
  required_version = ">= 0.14"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "1.5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.61.0"
    }
    kubernetes = {
        source = "hashicorp/kubernetes"
        version  = "2.2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {
}

provider "kubernetes" {
  host     = azurerm_kubernetes_cluster.cluster.kube_admin_config[0].host
  username = azurerm_kubernetes_cluster.cluster.kube_admin_config[0].username
  password = azurerm_kubernetes_cluster.cluster.kube_admin_config[0].password
  client_certificate = base64decode(
    azurerm_kubernetes_cluster.cluster.kube_admin_config[0].client_certificate,
  )
  client_key = base64decode(azurerm_kubernetes_cluster.cluster.kube_admin_config[0].client_key)
  cluster_ca_certificate = base64decode(
    azurerm_kubernetes_cluster.cluster.kube_admin_config[0].cluster_ca_certificate,
  )
}


# Variables

variable "name" {
  type        = string
  description = "Name of the Kubernetes cluster resources"
  default     = "funkyapp"
}

variable "location" {
  type        = string
  description = "Location of all resources"
  default     = "westeurope"
}

variable "cluster_admins_group_display_name" {
  type        = string
  description = "Display Name of the existing Azure AD Group to have Kubernetes cluster Admin role"
}

variable "deployment_name" {
  type        = string
  description = "Name of Application deployment"
  default     = "nginx"
}

variable "deployment_image_name" {
  type        = string
  description = "Application container source path"
  default     = "mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine"
}

variable "tags" {
  type        = map(string)
  description = "Key-value map of Tags for all resources"
  default = {
    Environment = "Development"
  }
}


# Data sources

data "azuread_group" "admins" {
  display_name = var.cluster_admins_group_display_name
}


# Underlying infrastructure

resource "azurerm_resource_group" "cluster" {
  name     = var.name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "cluster" {
  name                = var.name
  address_space       = ["10.0.0.0/8"]
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  tags                = azurerm_resource_group.cluster.tags
}

resource "azurerm_subnet" "cluster" {
  name                 = "cluster"
  resource_group_name  = azurerm_resource_group.cluster.name
  virtual_network_name = azurerm_virtual_network.cluster.name
  address_prefixes     = ["10.240.0.0/16"]
}

resource "azurerm_route_table" "cluster" {
  name                = "${azurerm_virtual_network.cluster.name}-${azurerm_subnet.cluster.name}"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
}

resource "azurerm_route" "cluster" {
  name                = "to-onprem"
  resource_group_name = azurerm_resource_group.cluster.name
  route_table_name    = azurerm_route_table.cluster.name
  address_prefix      = "192.168.0.0/16"
  next_hop_type       = "VirtualNetworkGateway"
}
resource "azurerm_route" "internet" {
  name                = "to-internet"
  resource_group_name = azurerm_resource_group.cluster.name
  route_table_name    = azurerm_route_table.cluster.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "Internet"
}

resource "azurerm_subnet_route_table_association" "cluster" {
  subnet_id      = azurerm_subnet.cluster.id
  route_table_id = azurerm_route_table.cluster.id
}

# Kubernetes Cluster infrastructure

resource "azurerm_user_assigned_identity" "cluster" {
  resource_group_name = azurerm_resource_group.cluster.name
  location            = azurerm_resource_group.cluster.location

  name = var.name
}

resource "azurerm_role_assignment" "cluster_join_vnet" {
  scope                = azurerm_virtual_network.cluster.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
}
resource "azurerm_role_assignment" "cluster_manage_routes" {
  scope                = azurerm_route_table.cluster.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
}

resource "azurerm_kubernetes_cluster" "cluster" {
  name                = var.name
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  tags                = azurerm_resource_group.cluster.tags
  dns_prefix          = var.name

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.cluster.id
  }
  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.cluster.id
    }
  }

  identity {
    type = "UserAssigned"
    user_assigned_identity_id = azurerm_user_assigned_identity.cluster.id
  }

  role_based_access_control {
    enabled = true
    azure_active_directory {
      managed = true
      admin_group_object_ids = [
        data.azuread_group.admins.id
      ]
      azure_rbac_enabled = true
    }
  }
  network_profile {
    network_plugin = "kubenet"
  }

  depends_on = [
    azurerm_role_assignment.cluster_join_vnet,
    azurerm_role_assignment.cluster_manage_routes
  ]
}

# Cluster Monitoring

resource "azurerm_log_analytics_workspace" "cluster" {
  name                = var.name
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  sku                 = "PerGB2018"
}

resource "azurerm_log_analytics_solution" "cluster" {
  solution_name         = "ContainerInsights"
  location              = azurerm_resource_group.cluster.location
  resource_group_name   = azurerm_resource_group.cluster.name
  workspace_resource_id = azurerm_log_analytics_workspace.cluster.id
  workspace_name        = azurerm_log_analytics_workspace.cluster.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

# Container Registry

resource "azurerm_container_registry" "acr" {
  name                     = var.name
  resource_group_name      = azurerm_resource_group.cluster.name
  location                 = azurerm_resource_group.cluster.location
  sku                      = "Standard"
  admin_enabled            = false  
  georeplication_locations = ["West Europe", "North Europe"]
}

resource "azurerm_role_assignment" "cluster_pull_from_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.cluster.kubelet_identity[0].object_id
}

# Container Application deployment

resource "kubernetes_namespace" "dev" {
  metadata {
    annotations = {
      name = "dev"
    }

    name = "dev"
  }
}

resource "kubernetes_deployment" "application" {
  metadata {
    name      = var.deployment_name
    namespace = kubernetes_namespace.dev.id
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = var.deployment_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.deployment_name
        }
      }

      spec {
        container {
          image = var.deployment_image_name
          name  = var.deployment_name
        }
      }
    }
  }
}

resource "kubernetes_service" "application" {
  metadata {
    name      = kubernetes_deployment.application.metadata[0].name
    namespace = kubernetes_deployment.application.metadata[0].namespace
  }
  spec {
    selector = {
      app = kubernetes_deployment.application.spec[0].template[0].metadata[0].labels.app
    }
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
