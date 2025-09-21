module "vault" {
  source    = "../eks_deployment"
  name      = "vault"
  namespace = "security-services"
  cluster_name = "your-cluster-name"
  domain_name  = "your-domain-name.aws.boeing.com"
  image     = "registry.web.boeing.com/bdsappfundamentals/vault:latest"
  image_pull_secret = "gitlab"
  type      = "deployment"
  replicas  = 1
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
}


resource "kubernetes_service" "main" {
  # Create this resource only if service.enabled is true
  count = var.service.enabled ? 1 : 0

  metadata {
      name      = var.name
    namespace = var.namespace
    labels = {
        app = var.name
    }

    # Dynamically build the annotations map, including only the ones provided
    annotations = merge(
      var.service.annotations.loadBalancerType != null ? { "service.beta.kubernetes.io/aws-load-balancer-type" = var.service.annotations.loadBalancerType } : {},
      var.service.annotations.loadBalancerScheme != null ? { "service.beta.kubernetes.io/aws-load-balancer-scheme" = var.service.annotations.loadBalancerScheme } : {},
      var.service.annotations.loadBalancerSubnets != null ? { "service.beta.kubernetes.io/aws-load-balancer-subnets" = var.service.annotations.loadBalancerSubnets } : {},
      var.service.annotations.loadBalancerProtocol != null ? { "service.beta.kubernetes.io/aws-load-balancer-protocol" = var.service.annotations.loadBalancerProtocol } : {},
      var.service.annotations.loadBalancerTargetType != null ? { "service.beta.kubernetes.io/aws-load-balancer-target-type" = var.service.annotations.loadBalancerTargetType } : {},
      var.service.annotations.sslCert != null ? {
        "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = var.service.annotations.sslCert
        "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = var.service.annotations.sslPorts
      } : {},
    )
  }

  spec {
    type = var.service.type

    selector = {
    app = var.name
    }

    port {
      name        = "http"
      port        = var.service.port
      target_port = var.service.target_port
      protocol    = "TCP"
    }

    external_traffic_policy = var.service.external_traffic_policy
  }
}

resource "kubernetes_secret" "runtime" {
  count = var.secrets_enabled ? 1 : 0

  metadata {
    name      = var.secrets_name
    namespace = var.namespace
  }

  data = var.secrets_data
  type = "Opaque" // <- This is the part we can improve
}