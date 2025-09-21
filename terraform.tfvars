name = "vault"
namespace = "security-services"
cluster_name = "your-cluster-name"
domain_name  = "your-domain-name.aws.boeing.com"
image = "registry.web.boeing.com/bdsappfundamentals/vault:latest"
image_pull_secret = "gitlab"
type = "deployment"
replicas = 1
ports = [
  {
    protocol    = "TCP"
    port        = 80
    target_port = 8200
  }
]
requests = {
  cpu    = "100m"
  memory = "500Mi"
}
limits = {
  cpu    = "500m"
  memory = "1Gi"
}
config_map_data = {
  PERSISTENCE_ENABLED = "true"
  STORAGE_CLASS       = "efs-sc"
  MOUNT_PATH          = "/vault/data"
  STORAGE_SIZE        = "1Gi"
}
secret_data = {
  SRES_API_TOKEN = ""
  SRES_USERNAME  = ""
}
role_arn = ""
secrets_enabled = false
secrets_name    = "vault-secrets"
secrets_data    = {}
secrets_type    = "Opaque"
