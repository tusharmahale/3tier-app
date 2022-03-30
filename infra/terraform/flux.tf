#########################
# Flux Application S3 Buckets for source


resource "aws_s3_bucket" "flux-cd-applications" {
  count  = length(var.application_names)
  bucket = "flux-cd-repo-${var.application_names[count.index]}"
}

resource "aws_s3_bucket_acl" "flux-cd-applications" {
  count  = length(var.application_names)
  bucket = aws_s3_bucket.flux-cd-applications[count.index].id
  acl    = "private"
}

###################################################################
# Install Flux

###################################################################
# EKS Service Account source-controller in flux-system ns Access for S3
#

resource "aws_iam_role" "flux-cd-source-controller" {
  name = join("-", [module.eks.cluster_id, "flux-cd-source-controller-role"])
  assume_role_policy = templatefile(join("/", [var.workspace_dir, "infra/terraform/config/templates/eks-oidc-trust.tpl"]),
    {
      aws_account_id = data.aws_caller_identity.current.account_id,
      oidc_url       = local.oidc_url,
      k8s_namespace  = "flux-system",
      k8s_sa         = "source-controller"
  })
}

resource "aws_iam_role_policy" "flux-cd-source-controller" {
  name_prefix = join("-", [module.eks.cluster_id, "flux-cd-source-controller-policy"])
  role        = aws_iam_role.flux-cd-source-controller.name
  policy = templatefile(join("/", [var.workspace_dir, "infra/terraform/config/flux/eks-flux-cd-source-repo-iam-policy.json"]),
    {
      flux-cd-source-repo-s3-bucket = "flux-cd-repo*"
  })
}

resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
}

data "kubectl_file_documents" "apply" {
  content = file(join("/", [var.workspace_dir, "infra/terraform/config/flux/flux-toolkit.yaml"]))
}


# Convert documents list to include parsed yaml data
locals {
  apply = [for v in data.kubectl_file_documents.apply.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
}

# Apply manifests on the cluster
resource "kubectl_manifest" "flux-apply" {
  for_each = { for v in local.apply : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [
    kubernetes_namespace.flux_system,
    kubectl_manifest.flux-source-controller,
  ]
  yaml_body = each.value
}

resource "kubectl_manifest" "flux-source-controller" {
  yaml_body = templatefile(join("/", [var.workspace_dir, "infra/terraform/config/flux/flux-source-controller.yaml"]),
    {
      source-controller-arn = aws_iam_role.flux-cd-source-controller.arn
  })
  depends_on = [
    kubernetes_namespace.flux_system,
    module.eks.cluster_id,
  ]
}

###################################################
# Apply flux manifests 

data "kubectl_file_documents" "flux_manifests" {
  content = file(join("/", [var.workspace_dir, "infra/terraform/config/flux/application_manifests.yaml"]))
}

# Convert documents list to include parsed yaml data
locals {
  flux_objects = [for v in data.kubectl_file_documents.flux_manifests.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
}

# Apply manifests on the cluster

resource "kubectl_manifest" "flux_objects_apply" {
  for_each = { for v in local.flux_objects : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [
    module.eks.cluster_id,
    aws_s3_bucket.flux-cd-applications,
    kubernetes_namespace.flux_system,
  ]
  yaml_body = each.value
}
