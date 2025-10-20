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
data "kubectl_file_documents" "rendered" {
  filename   = local.rendered_yaml
  depends_on = [null_resource.kustomize_build]
}

# Apply each document as a manifest
resource "kubectl_manifest" "apply" {
  for_each            = toset(data.kubectl_file_documents.rendered.documents)
  yaml_body           = each.value
  server_side_apply   = true
  force_conflicts     = true
  wait                = true
  wait_for_rollout    = true
}