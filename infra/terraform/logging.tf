#######################################################################
# Container Insights logging with cloudwatch for EC2 Node Containers

resource "kubernetes_namespace" "amazon-cloudwatch" {
  metadata {
    labels = {
      "name" = "amazon-cloudwatch"
    }
    name = "amazon-cloudwatch"
  }
  depends_on = [module.eks.cluster_id]
}

resource "kubernetes_config_map" "fluent-bit-cluster-info" {
  metadata {
    name      = "fluent-bit-cluster-info"
    namespace = "amazon-cloudwatch"
  }

  data = {
    "cluster.name" = module.eks.cluster_id
    "http.port"    = ""
    "http.server"  = "Off"
    "logs.region"  = var.aws_region
    "read.head"    = "Off"
    "read.tail"    = "On"
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.amazon-cloudwatch,
  ]
}

resource "kubernetes_service_account" "fluent-bit" {
  metadata {
    name      = "fluent-bit"
    namespace = "amazon-cloudwatch"
  }
  automount_service_account_token = true
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.amazon-cloudwatch,
  ]
}

resource "kubernetes_cluster_role" "fluent-bit-role" {
  metadata {
    name = "fluent-bit-role"
  }
  rule {
    non_resource_urls = ["/metrics"]
    verbs             = ["get"]
  }
  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "pods/logs"]
    verbs      = ["get", "list", "watch"]
  }
  depends_on = [
    module.eks.cluster_id,
  ]
}


resource "kubernetes_cluster_role_binding" "fluent-bit-role-binding" {
  metadata {
    name = "fluent-bit-role-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.fluent-bit-role.metadata.0.name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.fluent-bit.metadata.0.name
    namespace = kubernetes_service_account.fluent-bit.metadata.0.namespace
  }
  depends_on = [
    module.eks.cluster_id,
  ]
}

resource "kubernetes_config_map" "fluent-bit-config" {
  metadata {
    name      = "fluent-bit-config"
    namespace = "amazon-cloudwatch"
    labels = {
      "k8s-app" = "fluent-bit"
    }
  }
  data = {
    "fluent-bit.conf"      = file(join("/", [var.workspace_dir, "infra/terraform/config/fluentbit/fluent-bit.conf"]))
    "dataplane-log.conf"   = file(join("/", [var.workspace_dir, "infra/terraform/config/fluentbit/dataplane-log.conf"]))
    "application-log.conf" = file(join("/", [var.workspace_dir, "infra/terraform/config/fluentbit/application-log.conf"]))
    "parsers.conf"         = file(join("/", [var.workspace_dir, "infra/terraform/config/fluentbit/parsers.conf"]))
    "host-log.conf"        = file(join("/", [var.workspace_dir, "infra/terraform/config/fluentbit/host-log.conf"]))
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.amazon-cloudwatch,
  ]
}

resource "kubernetes_daemonset" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = "amazon-cloudwatch"
    labels = {
      k8s-app                         = "fluent-bit"
      "kubernetes.io/cluster-service" = "true"
      version                         = "v1"
    }
  }

  spec {
    selector {
      match_labels = {
        k8s-app = "fluent-bit"
      }
    }

    template {
      metadata {
        labels = {
          k8s-app                         = "fluent-bit"
          "kubernetes.io/cluster-service" = "true"
          version                         = "v1"
        }
      }

      spec {
        volume {
          name = "fluentbitstate"
          host_path {
            path = "/var/fluent-bit/state"
          }
        }

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "eks.amazonaws.com/compute-type"
                  operator = "NotIn"
                  values   = ["fargate"]
                }
              }
            }
          }
        }

        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }

        volume {
          name = "varlibdockercontainers"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }

        volume {
          name = "fluent-bit-config"
          config_map {
            name = "fluent-bit-config"
          }
        }

        volume {
          name = "runlogjournal"
          host_path {
            path = "/run/log/journal"
          }
        }

        volume {
          name = "dmesg"
          host_path {
            path = "/var/log/dmesg"
          }
        }

        container {
          name  = "fluent-bit"
          image = "public.ecr.aws/aws-observability/aws-for-fluent-bit:latest"

          env {
            name = "AWS_REGION"
            value_from {
              config_map_key_ref {
                name = "fluent-bit-cluster-info"
                key  = "logs.region"
              }
            }
          }

          env {
            name = "CLUSTER_NAME"
            value_from {
              config_map_key_ref {
                name = "fluent-bit-cluster-info"
                key  = "cluster.name"
              }
            }
          }

          env {
            name = "HTTP_SERVER"
            value_from {
              config_map_key_ref {
                name = "fluent-bit-cluster-info"
                key  = "http.server"
              }
            }
          }

          env {
            name = "HTTP_PORT"
            value_from {
              config_map_key_ref {
                name = "fluent-bit-cluster-info"
                key  = "http.port"
              }
            }
          }

          env {
            name = "READ_FROM_HEAD"
            value_from {
              config_map_key_ref {
                name = "fluent-bit-cluster-info"
                key  = "read.head"
              }
            }
          }

          env {
            name = "READ_FROM_TAIL"
            value_from {
              config_map_key_ref {
                name = "fluent-bit-cluster-info"
                key  = "read.tail"
              }
            }
          }

          env {
            name = "HOST_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name  = "CI_VERSION"
            value = "k8s/1.3.2"
          }

          resources {
            limits = {
              memory = "200Mi"
            }
            requests = {
              cpu    = "500m"
              memory = "100Mi"
            }
          }

          volume_mount {
            name       = "fluentbitstate"
            mount_path = "/var/fluent-bit/state"
          }

          volume_mount {
            name       = "varlog"
            read_only  = true
            mount_path = "/var/log"
          }

          volume_mount {
            name       = "varlibdockercontainers"
            read_only  = true
            mount_path = "/var/lib/docker/containers"
          }

          volume_mount {
            name       = "fluent-bit-config"
            mount_path = "/fluent-bit/etc/"
          }

          volume_mount {
            name       = "runlogjournal"
            read_only  = true
            mount_path = "/run/log/journal"
          }

          volume_mount {
            name       = "dmesg"
            read_only  = true
            mount_path = "/var/log/dmesg"
          }

          image_pull_policy = "Always"
        }

        termination_grace_period_seconds = 10
        service_account_name             = "fluent-bit"

        toleration {
          key      = "node-role.kubernetes.io/master"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        toleration {
          operator = "Exists"
          effect   = "NoExecute"
        }

        toleration {
          operator = "Exists"
          effect   = "NoSchedule"
        }
      }
    }
  }

  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.amazon-cloudwatch,
  ]
}

resource "kubernetes_network_policy" "egress_fluentbit_allow" {
  metadata {
    name      = "egress-fluentbit-allow"
    namespace = "amazon-cloudwatch"
  }

  spec {
    pod_selector {
      match_labels = {
        k8s-app = "fluent-bit"
      }
    }

    policy_types = ["Egress"]
    egress {}
  }
}

