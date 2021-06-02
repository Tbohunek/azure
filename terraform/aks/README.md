# Azure Kubernetes Cluster
This module deploys Azure Kubernetes cluster with following features:
- managed Azure Application Gateway as Ingress Controller in DMZ vnet
- enabled RBAC and Azure AD integration
- managed identities
- Azure CNI network plugin

It also deployes one simple container application.

## Requirements

No requirements.

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