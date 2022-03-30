variable "program_name" {
  description = "Enter program_name"
  type        = string
  default     = "dev-test"
}

variable "vpc_cidr" {
  description = "Enter VPC CIDR range"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Enter public_subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "Enter private_subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "azs" {
  description = "Enter vpc_azs"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "workspace_dir" {
  description = "Should be updated during terraform execution on jenkins agent"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "route53_domain" {
  description = "Route53 Domain"
  type        = string
  default     = "devopsguy.one"
}

variable "application_names" {
  description = "Applications"
  type        = list(string)
  default     = ["web-service", "api-service"]
}
