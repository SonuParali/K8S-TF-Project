# Map GitHub Actions IAM role into EKS aws-auth so CI kubectl can access
# Requires admin kubeconfig when running terraform apply


# Ensure eksctl is installed and create iamidentitymapping for the CI role
resource "null_resource" "map_github_actions_role" {
  depends_on = [aws_iam_role.gha_deploy]
  triggers = {
    role_arn        = aws_iam_role.gha_deploy.arn
    cluster_name    = var.eks_cluster_name
    region          = var.aws_region
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = "Stop"
      $Cluster = "${var.eks_cluster_name}"
      $Region  = "${var.aws_region}"
      $RoleArn = "${aws_iam_role.gha_deploy.arn}"

      Write-Host "Checking for eksctl..."
      $eksctlCmd = Get-Command eksctl -ErrorAction SilentlyContinue
      if (-not $eksctlCmd) {
        Write-Host "Installing eksctl locally..."
        $zipUrl = "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_windows_amd64.zip"
        $zipPath = Join-Path $env:TEMP "eksctl.zip"
        $destDir = Join-Path $env:TEMP "eksctl-bin"
        if (Test-Path $destDir) { Remove-Item -Recurse -Force $destDir }
        New-Item -ItemType Directory -Path $destDir | Out-Null
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $destDir -Force
        $eksctlExe = Get-ChildItem -Path $destDir -Recurse -Filter eksctl.exe | Select-Object -First 1
        if (-not $eksctlExe) { throw "Failed to install eksctl" }
        $env:PATH = "$($eksctlExe.DirectoryName);" + $env:PATH
      }

      Write-Host "Checking if IAM identity mapping exists for $RoleArn..."
      $existing = & eksctl get iamidentitymapping --cluster $Cluster --region $Region | Select-String -SimpleMatch $RoleArn
      if ($existing) {
        Write-Host "IAM identity mapping already exists. Skipping creation."
      }
      else {
        Write-Host "Creating IAM identity mapping for role $RoleArn..."
        & eksctl create iamidentitymapping --cluster $Cluster --region $Region --arn $RoleArn --group system:masters --username github-actions
        Write-Host "IAM identity mapping created."
      }
    EOT
  }
}