#!/usr/bin/bash

cd infra/terraform/
terraform version
terraform init -upgrade

echo $WORKSPACE

# terraform plan -refresh=false -no-color -lock=false 
# terraform plan -var "workspace_dir=${WORKSPACE}" -var-file=input.tfvars -refresh=${terraform_refresh} -lock=false || echo "Only terraform apply step"

[[ $1 == "plan" ]] && terraform plan -var "workspace_dir=${WORKSPACE}" -refresh=${terraform_refresh} -lock=false || echo "Only terraform apply step"
[[ $1 == "apply" ]] && terraform apply -var "workspace_dir=${WORKSPACE}" -refresh=${terraform_refresh} -auto-approve -lock=false || echo "Only terraform plan step"
