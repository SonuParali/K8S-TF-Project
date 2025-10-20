# Render Kustomize overlays and apply manifests via kubectl

variable "overlay_environment" {
  description = "Environment overlay to apply (dev|staging|prod)"
  type        = string
  default     = "dev"
}

locals {
  overlay_dir   = "${path.module}/../../k8s/overlays/${var.overlay_environment}"
  generated_dir = "${path.module}/.generated"
  rendered_yaml = "${local.generated_dir}/${var.overlay_environment}.yaml"
}

# Build kustomize overlay into a single YAML file (requires kustomize CLI)
resource "null_resource" "kustomize_build" {
  triggers = {
    overlay_dir = local.overlay_dir
  }

  provisioner "local-exec" {
    # PowerShell-friendly: create folder if missing, then write build output
    interpreter = ["PowerShell", "-Command"]
    command     = "if (!(Test-Path \"${local.generated_dir}\")) { New-Item -ItemType Directory -Path \"${local.generated_dir}\" | Out-Null }; kustomize build \"${local.overlay_dir}\" | Set-Content -Path \"${local.rendered_yaml}\""
  }
}

# Read multi-document YAML into individual documents
# Apply rendered YAML with kubectl (apply at terraform apply time)
resource "null_resource" "kubectl_apply" {
  depends_on = [null_resource.kustomize_build]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "kubectl apply -f \"${local.rendered_yaml}\""
  }
}