# DevOps Task: Scalable, Secure, Automated Deployment Pipeline

This repo demonstrates a full-stack microservices application deployed to AWS using containerization and Kubernetes orchestration configured on AWS, with CI/CD via GitHub Actions.

## Architecture Overview
- Frontend: React (Vite) served via NGINX container
- Backend: Express.js API
- Containerization: Docker with multi-stage builds
- Orchestration: Kubernetes manifests managed via Kustomize with dev/staging/prod overlays
- AWS: EKS for Kubernetes, ECR for container registry, S3 for static asset hosting, NGINX Ingress exposed via AWS LoadBalancer (ELB), CloudWatch for logs
- CI/CD: GitHub Actions builds, tests, pushes images to ECR, and deploys to EKS

## Repo Layout
```
frontend/        # React app (Vite)
backend/         # Express API
k8s/             # Kubernetes base & overlays (dev/staging/prod)
infra/terraform/ # Terraform skeleton for ECR, S3, OIDC (GitHub)
.github/workflows/ci-cd.yml # CI/CD pipeline
```

## Prerequisites
- Node.js 18+
- Docker
- AWS account with permissions for ECR, EKS, S3, IAM, Route 53, ACM
- kubectl and kustomize for local deployments (optional)
- GitHub repository with secrets configured

## Local Development
1. Backend
   ```bash
   cd backend
   npm ci
   npm run dev  # starts on http://localhost:4000
   ```
2. Frontend
   ```bash
   cd frontend
   npm ci
   npm run dev  # starts on http://localhost:5173, proxies /api → 4000
   ```
   The frontend fetches `GET /api/hello` and displays JSON.

## Containerization
- Frontend Dockerfile uses multi-stage build and NGINX.
- Backend Dockerfile runs production Node on `node:18-alpine`.
- `.dockerignore` files keep images lean.

Build locally:
```bash
docker build -t frontend:local ./frontend
docker build -t backend:local ./backend
```

## Kubernetes Manifests
- Base resources: Deployments, Services, Ingress, ConfigMap, Secret, HPAs
- Overlays: dev, staging, prod namespaces and environment-specific patches

Apply locally (assuming a kubeconfig):
```bash
kubectl apply -k k8s/overlays/dev
```

Ingress defaults to catch-all (no `host`) in base/dev/prod. Staging adds `host: staging.local`. TLS uses a placeholder secret. When you do not have a domain, see "Access Without a Domain" below.


## AWS Infrastructure (Terraform Skeleton)
- `infra/terraform` provides resources for:
  - ECR repositories (backend, frontend)
  - S3 bucket for static assets with public-read policy
  - IAM OIDC provider + role for GitHub Actions to assume

Initialize & apply:
```bash
cd infra/terraform
terraform init
terraform apply -var="aws_region=<region>" -var="project_name=<name>" -var="github_org=<org>" -var="github_repo=<repo>"
```

### EKS Cluster
This repo assumes an existing EKS cluster. The CI deploy job installs Nginx Ingress Controller via Helm (`ingress-nginx`) and exposes it as a `LoadBalancer` Service on AWS.

### Access Without a Domain
- Get the ingress address (AWS ELB hostname):
  ```bash
  kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
  ```
- Dev and Prod (hostless rules):
  - Routes match any `Host` header.
  - Access frontend: `https://<load-balancer-hostname>/`
  - Access backend: `https://<load-balancer-hostname>/api/hello`
  - If using placeholder certs, use `curl -k` or replace `tls-dev`/`tls-prod` with valid certs.
- Staging (host-based rule `staging.local`):
  - Option A (quick test): `curl -H "Host: staging.local" https://<load-balancer-hostname>/ -k`
  - Option B (hosts file): On Windows, edit `C:\Windows\System32\drivers\etc\hosts` and add `<ELB-IP> staging.local` (note: ELB IP can change).
  - Option C (catch-all): Edit `k8s/overlays/staging/patch-ingress.yaml` to remove `host: staging.local` and `tls.hosts`, keeping only `secretName`.
- TLS:
  - Secrets `tls-dev`, `tls-prod`, and `tls-placeholder` are placeholders. Replace with valid or self-signed certs for non-production.
  - Example (self-signed for staging):
    ```bash
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=staging.local"
    kubectl -n staging create secret tls tls-placeholder --key tls.key --cert tls.crt --dry-run=client -o yaml | kubectl apply -f -
    ```


## CI/CD Pipeline (GitHub Actions)
- Triggers on `main` and manual dispatch with `environment` input (`dev|staging|prod`)
- Steps:
  - Backend: Install + tests
  - Frontend: Install + build
  - Configure AWS creds via OIDC role
  - Login to ECR, build + push images with tag `${GITHUB_SHA}`
  - Optionally sync `frontend/dist` to S3
  - Deploy with kustomize overlays, set images to `${ECR_REGISTRY}/<service>:${GITHUB_SHA}`
  - Wait for rollout; rollback on failure

### Required GitHub Secrets
- `AWS_REGION` (e.g., `us-east-1`)
- `ECR_REGISTRY` (e.g., `<account>.dkr.ecr.<region>.amazonaws.com`)
- `EKS_CLUSTER_NAME`
- `ROLE_TO_ASSUME` (ARN from Terraform output `gha_role_arn`)
- `S3_BUCKET_NAME`
- Optional TLS per environment (to avoid committing certs/keys):
  - `TLS_CERT_DEV`, `TLS_KEY_DEV`
  - `TLS_CERT_STAGING`, `TLS_KEY_STAGING`
  - `TLS_CERT_PROD`, `TLS_KEY_PROD`

## Security
- No credentials hardcoded; use GitHub OIDC to assume role
- Kubernetes Secrets are placeholders; for production use:
  - AWS SSM Parameter Store or Secrets Manager
  - External Secrets operator to sync into Kubernetes
- NGINX serves static files; S3 bucket policy limits to public read of objects only

## Logging & Monitoring
- Use CloudWatch Container Insights or deploy Fluent Bit (aws-for-fluent-bit) for log shipping
- Optional: Prometheus/Grafana via Helm charts

## Scaling
- HPAs configured for backend and frontend (CPU target 60%)
- Adjust `minReplicas`, `maxReplicas`, and metrics as needed

## Rollback Strategy
- CI uses `kubectl rollout` to verify success
- On failure, `kubectl rollout undo` is executed
- Keep previous image tags to facilitate quick rollback

## Deployment Flow Summary
1. Push to `main` or manual run with environment input
2. CI runs tests and builds images
3. CI pushes images to ECR and updates kustomize overlay images
4. `kubectl apply -k` deploys to EKS namespace per environment
5. Nginx Ingress routes traffic; TLS via Kubernetes secret

## Notes
- Replace placeholders in k8s manifests and Terraform variables
- Ensure Nginx Ingress Controller is installed (CI deploy job installs it via Helm)
- For S3 website hosting with full HTTPS, consider CloudFront; ACM is not required without a domain

## Troubleshooting
- Image pull errors: confirm ECR repo exists and role has permissions
- Ingress not ready: verify Nginx Ingress is installed and `ingress-nginx-controller` Service has an external hostname
- 404 on `/api/hello`: ensure backend service is reachable; dev proxy is configured
