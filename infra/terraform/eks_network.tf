# VPC and Subnets

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.program_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
    program     = var.program_name
  }
}

module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name    = "${var.program_name}-vpc"
  cluster_version = "1.21"
  # cluster_endpoint_private_access = true
  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    managed_group = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types               = ["t3.large"]
      capacity_type                = "SPOT"
      subnet_ids                   = module.vpc.private_subnets
      iam_role_additional_policies = [aws_iam_policy.fluentbit.arn]
      labels = {
        program = var.program_name
      }
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
    program     = var.program_name
  }
}

# VPC endpoint for RDS

resource "aws_vpc_endpoint" "rds" {
  vpc_id            = module.vpc.vpc_id
  service_name      = join(".", ["com.amazonaws", var.aws_region, "rds"])
  vpc_endpoint_type = "Interface"
  security_group_ids = [
    module.eks.cluster_primary_security_group_id,
  ]
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = false
}


resource "aws_iam_policy" "fluentbit" {
  name   = "fluentbit_access"
  path   = "/"
  policy = file(join("/", [var.workspace_dir, "infra/terraform/config/policies/fluentbit_access.json"]))
}
