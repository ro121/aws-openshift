variable "name" {
  description = "Name of the app/service being deployed"
  type        = string
}

variable "namespace" {
  description = "Namespace to deploy into"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS Cluster"
  type        = string
}

variable "domain_name" {
  description = "FQDN for the domain"
  type        = string
}

variable "image" {
  description = "Container image for Vault"
  type        = string
}

variable "image_pull_secret" {
  description = "Image pull secret name"
  type        = string
}

variable "type" {
  description = "Type of resource (deployment, statefulset)"
  type        = string
}

variable "replicas" {
  description = "Number of Vault replicas"
  type        = number
}

variable "ports" {
  description = "List of ports to expose"
  type = list(object({
    protocol    = string
    port        = number
    target_port = number
  }))
}

variable "requests" {
  description = "Resource requests for Vault"
  type = object({
    cpu    = string
    memory = string
  })
}

variable "limits" {
  description = "Resource limits for Vault"
  type = object({
    cpu    = string
    memory = string
  })
}

variable "config_map_data" {
  description = "ConfigMap data for Vault"
  type        = map(string)
}

variable "secret_data" {
  description = "Secret data for Vault"
  type        = map(string)
}

variable "role_arn" {
  description = "IAM Role ARN for Vault service account"
  type        = string
}

variable "secrets_enabled" {
  description = "Enable creation of runtime secrets"
  type        = bool
  default     = false
}

variable "secrets_name" {
  description = "Name of the runtime secret"
  type        = string
  default     = ""
}

variable "secrets_data" {
  description = "Data for the runtime secret"
  type        = map(string)
  default     = {}
}

variable "secrets_type" {
  description = "Type of the runtime secret (e.g., Opaque)"
  type        = string
  default     = "Opaque"
}
