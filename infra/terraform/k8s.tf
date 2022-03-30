##################################################################
# AWS ingress controller setup

resource "aws_iam_role" "AmazonEKSLoadBalancerControllerRole" {
  name = join("-", [module.eks.cluster_id, "AmazonEKSLoadBalancerControllerRole"])
  assume_role_policy = templatefile(join("/", [var.workspace_dir, "infra/terraform/config/templates/eks-oidc-trust.tpl"]),
    {
      aws_account_id = data.aws_caller_identity.current.account_id,
      oidc_url       = local.oidc_url,
      k8s_namespace  = "kube-system",
      k8s_sa         = "aws-load-balancer-controller"
  })
}

resource "aws_iam_role_policy" "AWSLoadBalancerControllerIAMPolicy" {
  name_prefix = join("-", [module.eks.cluster_id, "AWSLoadBalancerControllerIAMPolicy"])
  role        = aws_iam_role.AmazonEKSLoadBalancerControllerRole.name
  policy      = file(join("/", [var.workspace_dir, "infra/terraform/config/policies/AWSLoadBalancerControllerIAMPolicy.json"]))
}

resource "kubernetes_service_account" "aws-load-balancer-controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.AmazonEKSLoadBalancerControllerRole.arn
    }
    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }
  }
  automount_service_account_token = true
  depends_on = [
    module.eks.cluster_id,
    kubernetes_namespace.application,
  ]
}

# resource "helm_release" "aws-load-balancer-controller" {
#   name       = "aws-load-balancer-controller"
#   repository = "https://aws.github.io/eks-charts"
#   chart      = "aws-load-balancer-controller"
#   namespace  = "kube-system"
#   # version    = "1.2.3"

#   set {
#     name  = "clusterName"
#     value = module.eks.cluster_id
#   }

#   set {
#     name  = "serviceAccount.create"
#     value = "false"
#   }

#   set {
#     name  = "serviceAccount.name"
#     value = "aws-load-balancer-controller"
#   }

#   depends_on = [
#     module.eks.cluster_id,
#     kubernetes_namespace.application,
#   ]

# }

# resource "kubernetes_network_policy" "egress_alb_controller_allow" {
#   metadata {
#     name      = "egress-alb-controller-allow"
#     namespace = "kube-system"
#   }

#   spec {
#     pod_selector {
#       match_labels = {
#         "app.kubernetes.io/name" = "aws-load-balancer-controller"
#       }
#     }

#     policy_types = ["Egress"]
#     egress {}
#   }
# }


# Ingress ALB controller for public access

resource "kubernetes_namespace" "application" {
  metadata {
    labels = {
      "name" = "application"
    }
    name = "application"
  }
  depends_on = [module.eks.cluster_id]
}

data "aws_acm_certificate" "domain" {
  domain   = var.route53_domain
  statuses = ["ISSUED"]
}

# resource "kubectl_manifest" "ingress" {
#   yaml_body = templatefile(join("/", [var.workspace_dir, "infra/terraform/config/ingress/ingress.yaml"]),
#     {
#       acm_certificate_arn = data.aws_acm_certificate.domain.arn,
#       # acm_certificate_arn = "Test Cert ARN",
#       public_subnets = join(", ", module.vpc.public_subnets)
#       route53_domain = var.route53_domain,
#       namespace      = kubernetes_namespace.application.metadata[0].name
#   })
#   depends_on = [
#     module.eks.cluster_id,
#     kubernetes_namespace.application,
#   ]
# }

