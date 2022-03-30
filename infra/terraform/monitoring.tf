# Prometheus installation

resource "kubernetes_namespace" "ns-monitoring" {
  metadata {
    annotations = {
      name = "monitoring"
    }
    labels = {
      name = "monitoring"
    }
    name = "monitoring"
  }
  depends_on = [module.eks.cluster_id]
}


resource "kubernetes_service_account" "prometheus_kube_state_metrics" {
  metadata {
    name      = "prometheus-kube-state-metrics"
    namespace = kubernetes_namespace.ns-monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/instance" = "prometheus"
      "app.kubernetes.io/name"     = "kube-state-metrics"
      "helm.sh/chart"              = "kube-state-metrics-2.9.7"
    }
  }

  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.ns-monitoring,
  ]
}

resource "kubernetes_service_account" "prometheus_node_exporter" {
  metadata {
    name      = "prometheus-node-exporter"
    namespace = kubernetes_namespace.ns-monitoring.metadata[0].name
    labels = {
      app       = "prometheus"
      chart     = "prometheus-13.2.1"
      component = "node-exporter"
      release   = "prometheus"
    }
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.ns-monitoring,
  ]
}

resource "kubernetes_service_account" "amp_iamproxy_ingest_service_account" {
  metadata {
    name      = "prometheus-sa"
    namespace = kubernetes_namespace.ns-monitoring.metadata[0].name
    labels = {
      app       = "prometheus"
      chart     = "prometheus-13.2.1"
      component = "server"
      release   = "prometheus"
    }
    # annotations = {
    #   "eks.amazonaws.com/role-arn" = aws_iam_role.prometheus-ingestion-role.arn
    # }
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.ns-monitoring,
  ]
}

resource "kubernetes_config_map" "prometheus_server" {
  metadata {
    name      = "prometheus-server"
    namespace = kubernetes_namespace.ns-monitoring.metadata[0].name
    labels = {
      app       = "prometheus"
      chart     = "prometheus-13.2.1"
      component = "server"
      release   = "prometheus"
    }
  }
  data = {
    "alerting_rules.yml" = file(join("/", [var.workspace_dir, "infra/terraform/config/prometheus/alerting_rules.yml"]))
    "alerts"             = file(join("/", [var.workspace_dir, "infra/terraform/config/prometheus/alerts"]))
    # "prometheus.yml"      = templatefile(join("/",[var.workspace_dir,"infra/terraform/config/prometheus/prometheus.yml"]),
    #                         {
    #                           prometheus-amp-workspace-id = aws_prometheus_workspace.amp-workspace.id,
    #                         })
    "prometheus.yml"      = file(join("/", [var.workspace_dir, "infra/terraform/config/prometheus/prometheus.yml"]))
    "recording_rules.yml" = file(join("/", [var.workspace_dir, "infra/terraform/config/prometheus/recording_rules.yml"]))
    "rules"               = file(join("/", [var.workspace_dir, "infra/terraform/config/prometheus/rules"]))
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.ns-monitoring,
  ]
}

resource "kubernetes_cluster_role" "prometheus_kube_state_metrics" {
  metadata {
    name = "prometheus-kube-state-metrics"
    labels = {
      "app.kubernetes.io/instance" = "prometheus"
      "app.kubernetes.io/name"     = "kube-state-metrics"
      "helm.sh/chart"              = "kube-state-metrics-2.9.7"
    }
  }
  rule {
    verbs      = ["list", "watch"]
    api_groups = ["", "batch", "extensions", "apps", "autoscaling", "networking.k8s.io", "policy", "storage.k8s.io", "admissionregistration.k8s.io", "certificates.k8s.io"]
    resources  = ["pods", "cronjobs", "nodes", "replicasets", "resourcequotas", "services", "statefulsets", "volumeattachments", "secrets", "storageclasses", "replicationcontrollers", "validatingwebhookconfigurations", "persistentvolumeclaims", "poddisruptionbudgets", "persistentvolumes", "namespaces", "jobs", "configmaps", "networkpolicies", "endpoints", "deployments", "ingresses", "daemonsets", "limitranges", "mutatingwebhookconfigurations", "horizontalpodautoscalers", "certificatesigningrequests"]
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.ns-monitoring,
  ]
}

resource "kubernetes_cluster_role" "prometheus_server" {
  metadata {
    name = "prometheus-server"
    labels = {
      app       = "prometheus"
      chart     = "prometheus-13.2.1"
      component = "server"
      release   = "prometheus"
    }
  }
  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "nodes/metrics", "services", "endpoints", "pods", "ingresses", "configmaps"]
  }
  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses/status", "ingresses"]
  }
  rule {
    verbs             = ["get"]
    non_resource_urls = ["/metrics"]
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.ns-monitoring,
  ]
}

resource "kubernetes_cluster_role_binding" "prometheus_kube_state_metrics" {
  metadata {
    name = "prometheus-kube-state-metrics"
    labels = {
      "app.kubernetes.io/instance" = "prometheus"
      "app.kubernetes.io/name"     = "kube-state-metrics"
      "helm.sh/chart"              = "kube-state-metrics-2.9.7"
    }
  }
  subject {
    kind      = "ServiceAccount"
    name      = "prometheus-kube-state-metrics"
    namespace = kubernetes_namespace.ns-monitoring.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "prometheus-kube-state-metrics"
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.ns-monitoring,
  ]
}

resource "kubernetes_cluster_role_binding" "prometheus_server" {
  metadata {
    name = "prometheus-server"
    labels = {
      app       = "prometheus"
      chart     = "prometheus-13.2.1"
      component = "server"
      release   = "prometheus"
    }
  }
  subject {
    kind      = "ServiceAccount"
    name      = "prometheus-sa"
    namespace = kubernetes_namespace.ns-monitoring.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "prometheus-server"
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.ns-monitoring,
  ]
}

resource "kubernetes_service" "prometheus_kube_state_metrics" {
  metadata {
    name      = "prometheus-kube-state-metrics"
    namespace = kubernetes_namespace.ns-monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/instance" = "prometheus"
      "app.kubernetes.io/name"     = "kube-state-metrics"
      "helm.sh/chart"              = "kube-state-metrics-2.9.7"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }
  spec {
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 8080
      target_port = "8080"
    }
    selector = {
      "app.kubernetes.io/instance" = "prometheus"
      "app.kubernetes.io/name"     = "kube-state-metrics"
    }
    type = "ClusterIP"
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.ns-monitoring,
  ]
}

resource "kubernetes_service" "prometheus_node_exporter" {
  metadata {
    name      = "prometheus-node-exporter"
    namespace = kubernetes_namespace.ns-monitoring.metadata[0].name
    labels = {
      app       = "prometheus"
      chart     = "prometheus-13.2.1"
      component = "node-exporter"
      release   = "prometheus"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
    }
  }
  spec {
    port {
      name        = "metrics"
      protocol    = "TCP"
      port        = 9100
      target_port = "9100"
    }
    selector = {
      app       = "prometheus"
      component = "node-exporter"
      release   = "prometheus"
    }
    cluster_ip = "None"
    type       = "ClusterIP"
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.ns-monitoring,
  ]
}

resource "kubernetes_service" "prometheus_server_headless" {
  metadata {
    name      = "prometheus-server-headless"
    namespace = kubernetes_namespace.ns-monitoring.metadata[0].name
    labels = {
      app       = "prometheus"
      chart     = "prometheus-13.2.1"
      component = "server"
      release   = "prometheus"
    }
  }
  spec {
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = "9090"
    }
    selector = {
      app       = "prometheus"
      component = "server"
      release   = "prometheus"
    }
    cluster_ip = "None"
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.ns-monitoring,
  ]
}

resource "kubernetes_service" "prometheus_server" {
  metadata {
    name      = "prometheus-server"
    namespace = kubernetes_namespace.ns-monitoring.metadata[0].name
    labels = {
      app       = "prometheus"
      chart     = "prometheus-13.2.1"
      component = "server"
      release   = "prometheus"
    }
  }
  spec {
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = "9090"
    }
    selector = {
      app       = "prometheus"
      component = "server"
      release   = "prometheus"
    }
    type             = "ClusterIP"
    session_affinity = "None"
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.ns-monitoring,
  ]
}

resource "kubernetes_daemonset" "prometheus_node_exporter" {
  metadata {
    name      = "prometheus-node-exporter"
    namespace = kubernetes_namespace.ns-monitoring.metadata[0].name
    labels = {
      app       = "prometheus"
      chart     = "prometheus-13.2.1"
      component = "node-exporter"
      release   = "prometheus"
    }
  }
  spec {
    selector {
      match_labels = {
        app       = "prometheus"
        component = "node-exporter"
        release   = "prometheus"
      }
    }
    template {
      metadata {
        labels = {
          app       = "prometheus"
          chart     = "prometheus-13.2.1"
          component = "node-exporter"
          heritage  = "Helm"
          release   = "prometheus"
        }
      }
      spec {
        volume {
          name = "proc"
          host_path {
            path = "/proc"
          }
        }
        volume {
          name = "sys"
          host_path {
            path = "/sys"
          }
        }
        volume {
          name = "root"
          host_path {
            path = "/"
          }
        }
        container {
          name  = "prometheus-node-exporter"
          image = "quay.io/prometheus/node-exporter:v1.0.1"
          args  = ["--path.procfs=/host/proc", "--path.sysfs=/host/sys", "--path.rootfs=/host/root", "--web.listen-address=:9100"]
          port {
            name           = "metrics"
            host_port      = 9100
            container_port = 9100
          }
          volume_mount {
            name       = "proc"
            read_only  = true
            mount_path = "/host/proc"
          }
          volume_mount {
            name       = "sys"
            read_only  = true
            mount_path = "/host/sys"
          }
          volume_mount {
            name              = "root"
            read_only         = true
            mount_path        = "/host/root"
            mount_propagation = "HostToContainer"
          }
          image_pull_policy = "IfNotPresent"
        }
        toleration {
          key      = "only-for-application-anchore-analyzer"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }
        service_account_name = "prometheus-node-exporter"
        host_network         = true
        host_pid             = true
        security_context {
          run_as_user     = 65534
          run_as_group    = 65534
          run_as_non_root = true
          fs_group        = 65534
        }
      }
    }
    strategy {
      type = "RollingUpdate"
    }
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.ns-monitoring,
  ]
}

resource "kubernetes_deployment" "prometheus_kube_state_metrics" {
  metadata {
    name      = "prometheus-kube-state-metrics"
    namespace = kubernetes_namespace.ns-monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/instance" = "prometheus"
      "app.kubernetes.io/name"     = "kube-state-metrics"
      "helm.sh/chart"              = "kube-state-metrics-2.9.7"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "kube-state-metrics"
      }
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/instance" = "prometheus"
          "app.kubernetes.io/name"     = "kube-state-metrics"
        }
      }
      spec {
        container {
          name  = "kube-state-metrics"
          image = "quay.io/coreos/kube-state-metrics:v1.9.7"
          args  = ["--collectors=certificatesigningrequests", "--collectors=configmaps", "--collectors=cronjobs", "--collectors=daemonsets", "--collectors=deployments", "--collectors=endpoints", "--collectors=horizontalpodautoscalers", "--collectors=ingresses", "--collectors=jobs", "--collectors=limitranges", "--collectors=mutatingwebhookconfigurations", "--collectors=namespaces", "--collectors=networkpolicies", "--collectors=nodes", "--collectors=persistentvolumeclaims", "--collectors=persistentvolumes", "--collectors=poddisruptionbudgets", "--collectors=pods", "--collectors=replicasets", "--collectors=replicationcontrollers", "--collectors=resourcequotas", "--collectors=secrets", "--collectors=services", "--collectors=statefulsets", "--collectors=storageclasses", "--collectors=validatingwebhookconfigurations", "--collectors=volumeattachments"]
          port {
            container_port = 8080
          }
          liveness_probe {
            http_get {
              path = "/healthz"
              port = "8080"
            }
            initial_delay_seconds = 5
            timeout_seconds       = 5
          }
          readiness_probe {
            http_get {
              path = "/"
              port = "8080"
            }
            initial_delay_seconds = 5
            timeout_seconds       = 5
          }
          image_pull_policy = "IfNotPresent"
        }
        service_account_name            = "prometheus-kube-state-metrics"
        automount_service_account_token = "true"
        security_context {
          run_as_user  = 65534
          run_as_group = 65534
          fs_group     = 65534
        }
      }
    }
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_service_account.prometheus_kube_state_metrics,
    kubernetes_namespace.ns-monitoring,
  ]
}

resource "kubernetes_stateful_set" "prometheus_server" {
  metadata {
    name      = "prometheus-server"
    namespace = kubernetes_namespace.ns-monitoring.metadata[0].name
    labels = {
      app       = "prometheus"
      chart     = "prometheus-13.2.1"
      component = "server"
      release   = "prometheus"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app       = "prometheus"
        component = "server"
        release   = "prometheus"
      }
    }
    template {
      metadata {
        labels = {
          app       = "prometheus"
          chart     = "prometheus-13.2.1"
          component = "server"
          heritage  = "Helm"
          release   = "prometheus"
        }
      }
      spec {
        volume {
          name = "config-volume"
          config_map {
            name = "prometheus-server"
          }
        }
        container {
          name  = "prometheus-server-configmap-reload"
          image = "jimmidyson/configmap-reload:v0.4.0"
          args  = ["--volume-dir=/etc/config", "--webhook-url=http://127.0.0.1:9090/-/reload"]
          volume_mount {
            name       = "config-volume"
            read_only  = true
            mount_path = "/etc/config"
          }
          image_pull_policy = "IfNotPresent"
        }
        container {
          name  = "prometheus-server"
          image = "quay.io/prometheus/prometheus:v2.24.0"
          args  = ["--storage.tsdb.retention.time=15d", "--config.file=/etc/config/prometheus.yml", "--storage.tsdb.path=/data", "--web.console.libraries=/etc/prometheus/console_libraries", "--web.console.templates=/etc/prometheus/consoles", "--web.enable-lifecycle"]
          port {
            container_port = 9090
          }
          volume_mount {
            name       = "config-volume"
            mount_path = "/etc/config"
          }
          volume_mount {
            name       = "storage-volume"
            mount_path = "/data"
          }
          liveness_probe {
            http_get {
              path = "/-/healthy"
              port = "9090"
            }
            initial_delay_seconds = 30
            timeout_seconds       = 10
            period_seconds        = 15
            success_threshold     = 1
            failure_threshold     = 3
          }
          readiness_probe {
            http_get {
              path = "/-/ready"
              port = "9090"
            }
            initial_delay_seconds = 30
            timeout_seconds       = 4
            period_seconds        = 5
            success_threshold     = 1
            failure_threshold     = 3
          }
          image_pull_policy = "IfNotPresent"
        }
        # container {
        #   name  = "aws-sigv4-proxy-sidecar"
        #   image = "public.ecr.aws/aws-observability/aws-sigv4-proxy:1.0"
        #   args  = ["--name", "aps", "--region", var.aws_region, "--host", join("",["aps-workspaces.",var.aws_region,".amazonaws.com"]), "--port", ":8005"]
        #   port {
        #     name           = "aws-sigv4-proxy"
        #     container_port = 8005
        #   }
        # }
        termination_grace_period_seconds = 300
        service_account_name             = "prometheus-sa"
        security_context {
          run_as_user     = 65534
          run_as_group    = 65534
          run_as_non_root = true
          fs_group        = 65534
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "storage-volume"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "8Gi"
          }
        }
      }
    }
    service_name          = "prometheus-server-headless"
    pod_management_policy = "OrderedReady"
  }
  depends_on = [
    module.eks.cluster_id,
    kubernetes_config_map.prometheus_server,
    kubernetes_namespace.ns-monitoring,
  ]
}

## Alert Manager for alerting

# resource "kubernetes_service_account" "prometheus_alertmanager" {
#   metadata {
#     name      = "prometheus-alertmanager"
#     namespace = "monitoring"
#     labels = {
#       app       = "prometheus"
#       component = "alertmanager"
#     }
#   }
# }

# resource "kubernetes_config_map" "prometheus_alertmanager" {
#   metadata {
#     name      = "prometheus-alertmanager"
#     namespace = "monitoring"
#     labels = {
#       app       = "prometheus"
#       component = "alertmanager"
#     }
#   }
#   data = {
#     "alertmanager.yml" = templatefile(join("/", [var.workspace_dir, "base/templates/config_files/alertmanager/alertmanager.yaml"]),
#       {
#         cluster_name    = "eks-${var.cluster_name}-${var.environment_type}",
#         integration-key = var.pagerduty_integration_key,
#     })
#   }
# }

# resource "kubernetes_persistent_volume_claim" "prometheus_alertmanager" {
#   metadata {
#     name      = "prometheus-alertmanager"
#     namespace = "monitoring"
#     labels = {
#       app       = "prometheus"
#       component = "alertmanager"
#     }
#   }
#   spec {
#     access_modes = ["ReadWriteOnce"]
#     resources {
#       requests = {
#         storage = "2Gi"
#       }
#     }
#   }
# }

# resource "kubernetes_cluster_role" "prometheus_alertmanager" {
#   metadata {
#     name = "prometheus-alertmanager"
#     labels = {
#       app       = "prometheus"
#       component = "alertmanager"
#     }
#   }
# }

# resource "kubernetes_cluster_role_binding" "prometheus_alertmanager" {
#   metadata {
#     name = "prometheus-alertmanager"
#     labels = {
#       app       = "prometheus"
#       component = "alertmanager"
#     }
#   }
#   subject {
#     kind      = "ServiceAccount"
#     name      = "prometheus-alertmanager"
#     namespace = "monitoring"
#   }
#   role_ref {
#     api_group = "rbac.authorization.k8s.io"
#     kind      = "ClusterRole"
#     name      = "prometheus-alertmanager"
#   }
# }

# resource "kubernetes_service" "prometheus_alertmanager" {
#   metadata {
#     name      = "prometheus-alertmanager"
#     namespace = "monitoring"
#     labels = {
#       app       = "prometheus"
#       component = "alertmanager"
#     }
#   }
#   spec {
#     port {
#       name        = "http"
#       protocol    = "TCP"
#       port        = 80
#       target_port = "9093"
#     }
#     selector = {
#       app       = "prometheus"
#       component = "alertmanager"
#     }
#     type             = "ClusterIP"
#     session_affinity = "None"
#   }
# }

# resource "kubernetes_deployment" "prometheus_alertmanager" {
#   metadata {
#     name      = "prometheus-alertmanager"
#     namespace = "monitoring"
#     labels = {
#       app       = "prometheus"
#       component = "alertmanager"
#     }
#   }
#   spec {
#     replicas = 1
#     selector {
#       match_labels = {
#         app       = "prometheus"
#         component = "alertmanager"
#       }
#     }
#     template {
#       metadata {
#         labels = {
#           app       = "prometheus"
#           component = "alertmanager"
#         }
#       }
#       spec {
#         volume {
#           name = "config-volume"
#           config_map {
#             name = "prometheus-alertmanager"
#           }
#         }
#         volume {
#           name = "storage-volume"
#           persistent_volume_claim {
#             claim_name = "prometheus-alertmanager"
#           }
#         }
#         container {
#           name  = "prometheus-alertmanager"
#           image = "quay.io/prometheus/alertmanager:v0.21.0"
#           args  = ["--config.file=/etc/config/alertmanager.yml", "--storage.path=/data", "--cluster.advertise-address=[$(POD_IP)]:6783", "--web.external-url=http://localhost:9093"]
#           port {
#             container_port = 9093
#           }
#           env {
#             name = "POD_IP"
#             value_from {
#               field_ref {
#                 api_version = "v1"
#                 field_path  = "status.podIP"
#               }
#             }
#           }
#           volume_mount {
#             name       = "config-volume"
#             mount_path = "/etc/config"
#           }
#           volume_mount {
#             name       = "storage-volume"
#             mount_path = "/data"
#           }
#           readiness_probe {
#             http_get {
#               path = "/-/ready"
#               port = "9093"
#             }
#             initial_delay_seconds = 30
#             timeout_seconds       = 30
#           }
#           image_pull_policy = "IfNotPresent"
#         }
#         container {
#           name  = "prometheus-alertmanager-configmap-reload"
#           image = "jimmidyson/configmap-reload:v0.4.0"
#           args  = ["--volume-dir=/etc/config", "--webhook-url=http://127.0.0.1:9093/-/reload"]
#           volume_mount {
#             name       = "config-volume"
#             read_only  = true
#             mount_path = "/etc/config"
#           }
#           image_pull_policy = "IfNotPresent"
#         }
#         service_account_name = "prometheus-alertmanager"
#         security_context {
#           run_as_user     = 65534
#           run_as_group    = 65534
#           run_as_non_root = true
#           fs_group        = 65534
#         }
#       }
#     }
#   }
# }

