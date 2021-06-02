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

resource "azurerm_virtual_network" "ingress" {
  name                = "${var.name}-ingress"
  address_space       = ["11.0.0.0/8"]
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  tags                = azurerm_resource_group.cluster.tags
}

resource "azurerm_subnet" "ingress" {
  name                 = "ingress"
  resource_group_name  = azurerm_resource_group.cluster.name
  virtual_network_name = azurerm_virtual_network.ingress.name
  address_prefixes     = ["11.1.0.0/16"]
}

resource "azurerm_virtual_network_peering" "clsuter_to_ingress" {
  name                         = "cluster-to-ingress"
  resource_group_name          = azurerm_resource_group.cluster.name
  virtual_network_name         = azurerm_virtual_network.cluster.name
  remote_virtual_network_id    = azurerm_virtual_network.ingress.id
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "ingress_to_cluster" {
  name                         = "ingress-to-cluster"
  resource_group_name          = azurerm_resource_group.cluster.name
  virtual_network_name         = azurerm_virtual_network.ingress.name
  remote_virtual_network_id    = azurerm_virtual_network.cluster.id
  allow_virtual_network_access = true
}


# Kubernetes Cluster infrastructure

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
    ingress_application_gateway {
      enabled = true
      subnet_id = azurerm_subnet.ingress.id
    }
  }

  identity {
    type = "SystemAssigned"
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
    network_plugin = "azure"
  }
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

resource "kubernetes_ingress" "application" {
  metadata {
    name      = kubernetes_service.application.metadata[0].name
    namespace = kubernetes_service.application.metadata[0].namespace
    annotations = {
      "kubernetes.io/ingress.class" = "azure/application-gateway"
    }
  }

  spec {
    rule {
      http {
        path {
          backend {
            service_name = kubernetes_service.application.metadata[0].name
            service_port = kubernetes_service.application.spec[0].port[0].target_port
          }

          path = "/"
        }
      }
    }
  }
}
