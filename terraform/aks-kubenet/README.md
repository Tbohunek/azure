# Azure Kubernetes Cluster
Unlike the [Oritinal AKS module](../aks/README.md), this module deploys Azure Kubernetes cluster with following features:
- bring your own Virtual Network and Route table
- enabled RBAC and Azure AD integration
- managed identities
- kubenet network plugin

It also deployes one simple internal container application.

This module is intended for scenarios with external Ingress Controller such as a centrally-managed Application Gateway.
It is also because [AGIC is currently unsupported with Kubenet](https://github.com/Azure/application-gateway-kubernetes-ingress/issues/931) as Application Gateway subnet does not have kubenet routes. This will hopefully change soon!

## Requirements

This module expects that you already have some infrastructure, mainly that you are familiar with Terraform and Azure CLI, and you have `Owner` access to your subscription, and that you are member of the AD group specified in `var.cluster_admins_group_display_name`.

To begin, log in to Azure CLI and select your subscription.
```azcli
az login
az account set -s <subscriptionId>
```

Then run `terraform apply`. If you wish to integrate with your code, you also need to set up `backend`, else it will be persisted in your current directory.

## Providers

| Name | Version |
|------|---------|
| azuread | 1.5.0 |
| azurerm | 2.61.0 |
| kubernetes | 2.2.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | "Name of the Kubernetes cluster resources" | `string` | `funkyapp` | no |
| location | "Location of all resources" | `string` | `westeurope` | no |
| cluster_admins_group_display_name | "Display Name of the existing Azure AD Group to have Kubernetes cluster Admin role" | `string` | n/a | yes |
| deployment_name | "Name of Application deployment" | `string` | `nginx` | no|
| deployment_image_name | "Application container source path" | string | `mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine` | no |
| tags | Key-value map of Tags for all resources" | `map(string)` | `{Environment = "Development"}` | no |

## Outputs

No outputs.