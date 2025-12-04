# GitOps Kubernetes Platform on EKS

This repository contains a well-structured **GitOps-based Kubernetes platform** running on **Amazon EKS**, provisioned via **Terraform** and continuously reconciled with **FluxCD**.  

It includes:

- An **EKS cluster** with managed node group
- **FluxCD** bootstrap pointing to this Git repository
- A sample **NGINX application** deployed via a custom Helm chart
- **Autoscaling** via Horizontal Pod Autoscaler (HPA)
- **Automated image updates** using Flux Image Automation
- A full **observability stack**:
  - `kube-prometheus-stack` (Prometheus, Alertmanager, node-exporter, kube-state-metrics, Grafana)
  - `loki-stack` for logs
  - Grafana automatically wired to Loki as a data source

The goal is to demonstrate a realistic GitOps setup that you can extend for production workloads.

---

## 1. Repository Structure

```text
.
├── charts/
│   └── nginx/
│       ├── Chart.yaml                            # Helm chart metadata (name, version, description)
│       ├── values.yaml                           # Default configuration values for the NGINX chart
│       └── templates/                            # Kubernetes manifests rendered by Helm
│           ├── deployment.yaml                   # NGINX Deployment (container, probes, resources, metrics port)
│           ├── service.yaml                      # ClusterIP Service exposing NGINX (port 80)
│           ├── hpa.yaml                          # HorizontalPodAutoscaler (CPU-based auto-scaling)
│           └── servicemonitor.yaml               # Prometheus scrape configuration (ServiceMonitor CRD)
│
├── clusters/
│   └── staging/
│       ├── kustomization.yaml                    # Root of the staging environment: imports apps, Flux, monitoring
│
│       ├── apps/
│       │   └── nginx/
│       │       ├── helmrelease.yaml              # Flux HelmRelease managing the NGINX Helm chart in staging
│       │       └── kustomization.yaml            # Kustomize wrapper enabling reconciliation for this app
│
│       ├── flux/
│       │   ├── image-policy-nginx.yaml           # Defines allowed NGINX image version range (semver policy)
│       │   ├── image-repository-nginx.yaml       # Tracks NGINX upstream tags via Flux Image Reflector
│       │   ├── image-update-nginx.yaml           # Automates version bumps in Git (Image Automation)
│       │   └── kustomization.yaml                # Reconciles all Flux image-automation resources
│
│       └── monitoring/
│           ├── helmrepository-grafana.yaml       # Grafana official Helm repo reference
│           ├── helmrepository-prometheus.yaml    # Prometheus Community Helm repo reference
│           ├── kube-prometheus-helmrelease.yaml  # Kube-Prometheus-Stack (Prometheus + Grafana)
│           ├── loki-helmrelease.yaml             # Loki HelmRelease for log aggregation
│           └── kustomization.yaml                # Monitoring stack reconciliation entrypoint
│
└── terraform/
    ├── main.tf                                   # Root Terraform file: modules + Flux provider configuration
    ├── cluster.tf                                # EKS cluster module (VPC, node groups, networking)
    ├── flux-bootstrap.tf                         # Flux installation + Git bootstrap
    ├── monitoring-secrets.tf                     # Terraform-managed Grafana admin credentials (Secret)
    ├── providers.tf                              # AWS, Kubernetes, Helm, Flux providers
    ├── variables.tf                              # Input variables (VPC CIDRs, node size, versions)
    ├── outputs.tf                                # Outputs: kubeconfig data, cluster name, etc.
    ├── terraform.tfvars.example                  # Example configuration for users
    └── (local-only files: terraform.tfvars, terraform.tfstate, tfplan, ...)
```

> **Note**  
> Files like `terraform.tfstate`, `tfplan`, and the SSH private key are intentionally **not** meant to be committed. They are local-only artifacts and must remain outside of version control.

---

## 2. Prerequisites

You need the following tools installed locally:

- **AWS CLI** v2  
  Used for authentication and for generating `kubeconfig`.
- **Terraform** >= 1.7  
  Infrastructure provisioning (VPC, EKS, Flux bootstrap, Grafana admin secret).
- **kubectl**  
  To interact with the Kubernetes cluster.
- **Helm** >= 3  
  Required by the `helm_release` provider and for local chart testing.
- **Flux CLI**  
  For debugging and on-demand reconciliation.
- **Git**  
  To clone and push to your Git repository.

On Windows, make sure:

- You run commands from **PowerShell** or **cmd** with the tools available in `PATH`.
- `ssh.exe` is available (either via Git for Windows or OpenSSH client).

You also need:

- An **AWS account**.
- An **IAM user or role** with sufficient permissions to create EKS, VPC, IAM roles, LoadBalancers, and related resources.  
  For simplicity, development/testing can use `AdministratorAccess`. In production you would restrict this.

---

## 3. What This Platform Implements

High-level capabilities:

1. **Infrastructure as Code (Terraform)**
   - VPC with public and private subnets.
   - EKS cluster with one managed node group (e.g. `t3.medium` nodes).
   - Required EKS addons (vpc-cni, coredns, kube-proxy, eks-pod-identity-agent).
   - AWS IAM configuration via EKS module (`enable_cluster_creator_admin_permissions = true`).

2. **GitOps (FluxCD)**
   - Flux bootstrap into the `flux-system` namespace.
   - GitRepository pointing at this repo via SSH deploy key.
   - Kustomization for the `staging` environment:
     - Applications (NGINX)
     - Flux Image Automation
     - Monitoring stack

3. **Application Layer**
   - Custom **Helm chart** for `nginx`:
     - Deployment, Service, HPA, ServiceMonitor.
     - Configurable via `values.yaml`.
   - Flux **HelmRelease** for NGINX, deployed into `staging` namespace.
   - HPA configured to scale based on CPU usage.

4. **Image Automation**
   - Flux **ImageRepository** tracking Docker Hub `nginx` images.
   - Flux **ImagePolicy** pinned to the `1.29.x` semver range.
   - Flux **ImageUpdateAutomation** committing updates to `helmrelease.yaml` when a new patch is available.
   - Commit messages are automatically generated.

5. **Observability**
   - **kube-prometheus-stack** HelmRelease:
     - Prometheus
     - Alertmanager
     - kube-state-metrics
     - node-exporter
     - Grafana (exposed via LoadBalancer)
   - **loki-stack** HelmRelease:
     - Loki for logs
   - Grafana automatically wired with a **Loki datasource** via `additionalDataSources`.
   - ServiceMonitor for NGINX metrics so Prometheus can scrape it.

6. **Secrets Management (dev-level)**
   - Grafana admin user and password created as a **Kubernetes Secret** via Terraform.
   - Secret is **not** stored in Git (only generated from Terraform).

---

## 4. Deployment Guide (Step by Step)

This section walks through **end-to-end deployment** on a fresh account.

### 4.1. AWS Configuration

1. **Configure AWS CLI**

```bash
aws configure
# AWS Access Key ID: <your access key>
# AWS Secret Access Key: <your secret>
# Default region name: eu-central-1
# Default output format: json
```

2. **Validate identity and region**

```bash
aws sts get-caller-identity
aws ec2 describe-availability-zones --region eu-central-1
```

---

### 4.2. Fork and Clone the Repository

```bash
git clone git@github.com:<your-account>/gitops-k8s-platform.git
cd gitops-k8s-platform
```

---

### 4.3. Generate SSH Deploy Key for Flux

Flux uses SSH to pull this Git repository from GitHub.

From the `terraform` directory:

```bash
cd terraform

ssh-keygen -t ed25519 -C "flux-deploy-key" -f flux-id-ed25519
# This creates:
#   flux-id-ed25519      (private key)
#   flux-id-ed25519.pub  (public key)
```

Then:

1. Go to your GitHub repository settings:  
   **Settings → Deploy keys → Add deploy key**
2. Paste the contents of `flux-id-ed25519.pub`.
3. Give it a name like `flux-gitops-key`.
4. Check **"Allow write access"** (Flux must be able to push image tag updates).
5. Save.

> The private key `flux-id-ed25519` stays on disk only and is used by the Terraform Flux provider.  
> It is ignored via `.gitignore`.

---

### 4.4. Prepare Terraform Variables

In `terraform/`:

1. Copy example file:

```bash
copy terraform.tfvars.example terraform.tfvars   # Windows
# or
cp terraform.tfvars.example terraform.tfvars     # Linux/Mac
```

2. Edit `terraform.tfvars` and adjust as needed:

```hcl
aws_region         = "eu-central-1"
cluster_name       = "gitops-eks-cluster"
vpc_cidr           = "10.0.0.0/16"
private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
eks_version        = "1.33"
node_instance_type = "t3.medium"

node_min_size      = 2
node_max_size      = 4
node_desired_size  = 2
```

---

### 4.5. Terraform Init, Plan, Apply

From `terraform/`:

```bash
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

What this does:

- Creates VPC, subnets, routing, NAT gateway.
- Creates the EKS cluster and managed node group.
- Installs required EKS addons (vpc-cni, coredns, kube-proxy, eks-pod-identity-agent).
- Bootstraps Flux using `flux_bootstrap_git`:
  - Deploys Flux controllers into the `flux-system` namespace.
  - Configures GitRepository pointing to *this* repo via SSH.
  - Applies `clusters/staging` Kustomization, which then deploys:
    - `nginx` HelmRelease
    - Flux image automation resources
    - kube-prometheus-stack + loki-stack
- Creates `grafana-admin` Kubernetes secret in the `monitoring` namespace.

Apply may take several minutes while EKS nodes and LoadBalancers come up.

---

### 4.6. Configure `kubeconfig` for EKS

After Terraform apply succeeded:

```bash
aws eks update-kubeconfig --name gitops-eks-cluster --region eu-central-1

# Validate connectivity
kubectl get nodes
kubectl get ns
```

You should see worker nodes and namespaces like `kube-system`, `flux-system`, `monitoring`, `staging`.

---

### 4.7. Verify Flux Bootstrap

Check that Flux controllers are running:

```bash
kubectl get pods -n flux-system
```

Typical pods:

- `source-controller`
- `kustomize-controller`
- `helm-controller`
- `notification-controller`
- `image-reflector-controller`
- `image-automation-controller`

Check Git source and Kustomization:

```bash
flux get sources git -A
flux get kustomizations -A
```

You should see:

- `GitRepository/flux-system` in namespace `flux-system`
- `Kustomization/flux-system` in namespace `flux-system`
- `Kustomization/staging` (depending on how you wire environments)

To force a sync:

```bash
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization flux-system -n flux-system
```

---

### 4.8. Verify Application Deployment (NGINX)

Check HelmRelease:

```bash
kubectl get helmreleases -A | findstr nginx   # Windows
# or
kubectl get helmreleases -A | grep nginx
```

Check application resources in the `staging` namespace:

```bash
kubectl get deploy,svc,hpa -n staging
kubectl get servicemonitors -n monitoring | findstr nginx
```

You should see:

- `Deployment/nginx-app`
- `Service/nginx-svc`
- `HorizontalPodAutoscaler/nginx-hpa`
- `ServiceMonitor/nginx-servicemonitor` (name may differ slightly)

To port-forward NGINX:

```bash
kubectl port-forward -n staging deploy/nginx-app 8080:80
# Then open http://localhost:8080
```

---

### 4.9. Verify Monitoring Stack

#### 4.9.1. Prometheus

```bash
kubectl get svc -n monitoring monitoring-kube-prometheus-prometheus
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090
# Then open:
#   http://localhost:9090/targets
```

You should see targets for:

- `kubernetes-apiservers`
- `kubernetes-nodes`
- `kubernetes-pods`
- `kube-state-metrics`
- `node-exporter`
- And the NGINX ServiceMonitor.

#### 4.9.2. Grafana

Get Grafana service and admin password:

```bash
kubectl get svc monitoring-kube-prometheus-stack-grafana -n monitoring

kubectl get secret grafana-admin -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d
echo
```

Port-forward Grafana:

```bash
kubectl port-forward svc/monitoring-kube-prometheus-stack-grafana -n monitoring 3000:80
# Open:
#   http://localhost:3000
# Login with:
#   user: admin
#   password: <decoded password>
```

Check under **Connections → Data sources** that:

- Prometheus is configured
- Loki datasource is present (name `loki` or similar) and shows *"Data source is working"*.

#### 4.9.3. Loki

Verify Loki service:

```bash
kubectl get svc monitoring-loki-stack -n monitoring
kubectl port-forward svc/monitoring-loki-stack -n monitoring 3100:3100
# Then:
curl http://localhost:3100/ready
```

In Grafana → **Explore**, switch the datasource to **Loki** and query logs, for example:

```logql
{namespace="staging"}
```

---

### 4.10. Verify Image Automation

List image repositories, policies, and automations:

```bash
flux get image repository -n flux-system
flux get image policy -n flux-system
flux get image update -n flux-system
```

The configuration uses:

- `ImageRepository/nginx` – tracks Docker Hub `nginx` tags.
- `ImagePolicy/nginx-patch` – selects the highest `1.29.x` tag.
- `ImageUpdateAutomation/nginx-auto-update` – updates the NGINX HelmRelease when a new patch appears.

The HelmRelease snippet:

```yaml
image:
  repository: nginx
  tag: "1.29.3" # {"$imagepolicy": "flux-system:nginx-patch:tag"}
```

Flux will rewrite only the tag value, based on the policy.

To trigger a manual run:

```bash
flux reconcile image repository nginx -n flux-system
flux reconcile image policy nginx-patch -n flux-system
flux reconcile image update nginx-auto-update -n flux-system
```

Then check Git history — Flux should commit a message like:

```text
ci(flux): auto-update nginx image 1.29.3 -> 1.29.4
```

(assuming a new patch version exists).

---

## 5. Testing & Debugging Guide

This section collects **useful commands** for troubleshooting by layer.

### 5.1. Terraform / Infrastructure

Validate configuration:

```bash
cd terraform
terraform validate
terraform plan
```

Destroy cluster (for a full reset):

```bash
terraform destroy
```

If EKS node group fails with `NodeCreationFailure`:

- Ensure EKS version and module version are compatible.
- Ensure addons (especially `vpc-cni`) are configured as per module examples.
- Check that instance type (`t3.medium`) has enough CPU/memory.
- Check CloudWatch / EKS events for details.

---

### 5.2. Kubernetes Cluster

Basic sanity checks:

```bash
kubectl get nodes -o wide
kubectl get ns
kubectl get pods -A
```

Describe failing pods:

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

---

### 5.3. Flux

Useful commands:

```bash
flux get sources git -A
flux get kustomizations -A
flux get helmreleases -A
flux get image repository -A
flux get image policy -A
flux get image update -A
```

Force reconciliation:

```bash
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization flux-system -n flux-system
flux reconcile helmrelease nginx -n flux-system --with-source
```

Check Flux controller logs:

```bash
kubectl logs deploy/source-controller -n flux-system
kubectl logs deploy/kustomize-controller -n flux-system
kubectl logs deploy/helm-controller -n flux-system
kubectl logs deploy/image-reflector-controller -n flux-system
kubectl logs deploy/image-automation-controller -n flux-system
```

---

### 5.4. Helm / Application

Render chart locally:

```bash
helm template test ./charts/nginx --namespace staging
```

Check release status:

```bash
kubectl get helmreleases -A
kubectl describe helmrelease nginx -n flux-system
```

If HelmRelease is stuck:

- Look at `.status.conditions` in `kubectl describe`.
- Check events around `HelmChart` CR:

```bash
kubectl get helmcharts -A
kubectl describe helmchart flux-system-nginx -n flux-system
```

---

### 5.5. HPA & Scaling

Check HPA:

```bash
kubectl get hpa -n staging
kubectl describe hpa nginx-hpa -n staging
```

To generate load you can run a simple load pod:

```bash
kubectl run -n staging curl-loader --image=radial/busyboxplus:curl -it --rm \
  -- /bin/sh
# Inside the pod, run:
#   while true; do curl -s nginx-svc.staging.svc.cluster.local > /dev/null; done
```

Monitor replicas:

```bash
kubectl get deploy -n staging nginx-app -w
```

HPA is configured at:

- `minReplicas: 1`
- `maxReplicas: 5`
- `targetCPUUtilizationPercentage: 75`

---

### 5.6. Prometheus & ServiceMonitor

Check that the NGINX ServiceMonitor exists:

```bash
kubectl get servicemonitors -n monitoring
kubectl describe servicemonitor nginx-servicemonitor -n monitoring
```

In Prometheus UI:

- Go to **Status → Targets**, verify that the nginx job is up.
- Run a simple query:

```promql
up{job="nginx"}
```

---

### 5.7. Loki & Grafana Logs

Verify Loki:

```bash
kubectl get pods -n monitoring | findstr loki
kubectl logs -n monitoring <loki-pod-name>
```

Port-forward and check readiness:

```bash
kubectl port-forward svc/monitoring-loki-stack -n monitoring 3100:3100
curl http://localhost:3100/ready
```

In Grafana:

- Open **Explore** → select **Loki** datasource.
- Basic query:

```logql
{namespace="staging"}
```

or:

```logql
{app="nginx"}
```

---

## 6. Challenges & Assumptions

This section documents the real-world issues encountered and design trade-offs made.

### 6.1. EKS Version & Node Creation Failures

While using recent EKS versions (1.33) with new versions of `terraform-aws-modules/eks`, was hit:

```text
NodeCreationFailure: Unhealthy nodes in the kubernetes cluster
```

Root causes & mitigation:

- Newer EKS modules require explicit configuration of addons:
  - `vpc-cni`
  - `coredns`
  - `kube-proxy`
  - `eks-pod-identity-agent`
- Without correct addon configuration, nodes remained `NotReady`.

**Resolution:**

- Followed the official module examples and added an `addons` block.
- Ensured `enable_cluster_creator_admin_permissions = true` so the caller has immediate cluster admin rights.

### 6.2. Flux Bootstrap & Provider Wiring

A common pitfall is trying to use `data "aws_eks_cluster"` **before** the cluster exists.  
Instead, this setup uses module outputs from `module.eks` to configure:

- `kubernetes` provider
- `helm` provider
- `flux` provider

This avoids circular dependencies and allows running `terraform plan` in a single pass.

### 6.3. Image Automation API Changes

Flux Image APIs evolved:

- Old examples use `image.toolkit.fluxcd.io/v1beta2` and `.Updated` fields.
- Newer versions use `v1` and `.Changed` in commit templates.

Was adapted to:

- `apiVersion: image.toolkit.fluxcd.io/v1`
- `messageTemplate` using `.Changed.Images.0.OldTag` / `.Changed.Images.0.NewTag`.

Also:

- Flux was initially breaking the `image` value by injecting the full `nginx:<tag>` instead of just `<tag>`.
- This was solved by annotating the HelmRelease image block explicitly:

  ```yaml
  tag: "1.29.3" # {"$imagepolicy": "flux-system:nginx-patch:tag"}
  ```

so Flux knows to update only the `tag`.

### 6.4. Sealed Secrets on Windows

It was initially planned to integrate **Sealed Secrets**:

- Deployed the controller.
- Tried to use `kubeseal` locally on Windows.

Issues:

- `kubeseal` CLI could not reach the controller service (timeouts).
- Helm-based installation conflicted with the manually applied controller manifest.

Given the time constraints and the fact that this is a challenge environment, the decision was made:

- **Not** to use SealedSecrets.
- Rely on Terraform-managed K8s secret for Grafana admin credentials.

In production, using SealedSecrets or External Secrets (e.g., from AWS Secrets Manager) would be strongly recommended.

### 6.5. Instance Sizing and Pod Scheduling

At some point, the cluster reported:

```text
0/1 nodes are available: 1 Too many pods.
```

This was due to:

- Node size being too small.
- Multiple system pods (Prometheus stack, Loki, Flux) competing for resources.

Fix:

- Increased node instance type from `t3.small` to `t3.medium`.
- Increased node count to 2.

---

## 7. Production Hardening & Improvements

This repository is intentionally focused on a **single-environment (staging) demo**.  
For a production-ready platform, consider the following:

### 7.1. Terraform

- Use a **remote backend** (S3 + DynamoDB) instead of local `terraform.tfstate`.
- Split into separate stacks:
  - Networking (VPC)
  - EKS
  - Platform (Flux, monitoring, add-ons)
- Implement **least-privilege IAM** (role assumption) instead of `AdministratorAccess`.

### 7.2. Cluster & Nodes

- Configure **Cluster Autoscaler** for dynamic node scaling.
- Use **multiple node groups**:
  - system / critical components
  - workloads (apps)
  - optional GPU nodes for ML workloads.
- Enable and tune **Pod Security Standards** or PSP replacements (admission policies).
- `SPOT` instances were used for the cost-saving, use `ON_DEMAND` in production-like environment.

### 7.3. Security & Secrets

- Replace plain K8s `Secret` with:
  - **SealedSecrets** (Bitnami)  
  - or **ExternalSecrets** from AWS Secrets Manager / SSM Parameter Store.
- Enable TLS for Grafana, Prometheus, and Loki:
  - Either via Ingress + cert-manager
  - Or via AWS ALB with ACM certificates.
- Restrict access to the Prometheus/Grafana LoadBalancers using:
  - Internal LBs, or
  - Security groups and/or AWS WAF.

### 7.4. GitOps Layout

- Split into environments:

  ```text
  clusters/
    dev/
    staging/
    prod/
  ```

- Use **separate Git branches** and promotion pipelines.
- Add policies to prevent direct commits to `main` without PR review.

### 7.5. Observability Enhancements

- Add **Alertmanager** routes and receivers (Slack, Teams, email).
- Add **Grafana dashboards** stored as ConfigMaps or as dashboards provisioned via Helm values.
- Configure **log retention** and storage (e.g., S3 for Loki chunks).

### 7.6. CI/CD Integration

- Integrate Terraform with a CI system (GitHub Actions, GitLab CI, etc.).
- Run:
  - `terraform fmt`, `terraform validate`, `tflint`
  - `kubectl kustomize` linting
  - `helm lint` for charts
- Use pipelines to apply changes into staging/prod in a controlled way.

---

## 8. Summary

This repository demonstrates a complete **GitOps-centric Kubernetes platform** on top of AWS EKS:

- EKS provisioned with Terraform.
- Flux bootstrapped via Terraform and configured to track this Git repo.
- NGINX workloads delivered through a custom Helm chart and HelmRelease.
- Automatic image updates via Flux Image Automation.
- Autoscaling via HPA.
- Full observability with kube-prometheus-stack + Loki + Grafana, all wired together.
- Basic but realistic handling of secrets and access patterns.

The structure and decisions here were made to implement a robust staging environment, while leaving clear pathways for production hardening.

---

## 9. Project Use Cases

This project can be used in several practical scenarios:

### 1. Foundation for Your Own GitOps Platform
A solid starting point for building a production-ready GitOps platform on AWS EKS.  
You can extend the structure with additional environments, workloads, secrets management, and CI/CD integration.

### 2. Reference Implementation for Interviews & Technical Challenges
A clean, realistic example of:
- Terraform-managed EKS infrastructure  
- GitOps reconciliation with FluxCD  
- HelmRelease workflows  
- Observability stack integration  

Ideal for demonstrating platform engineering skills in interviews, coding challenges, or portfolio presentations.

### 3. Learning & Experimentation Environment
A safe sandbox for exploring:
- Kubernetes on AWS EKS  
- GitOps workflows with FluxCD  
- Helm chart development  
- Prometheus, Loki, and Grafana observability patterns  

Perfect for hands-on practice without touching production systems.

### 4. Blueprint for Multi-Environment GitOps Architecture
The staging layout can easily be expanded into:
- `dev → staging → prod` environments  
- Branch-based or tag-based promotion  
- Environment-specific Kustomize overlays  

Useful as a template when designing a real multi-environment GitOps workflow.

### 5. Teaching & Team Onboarding Material
Because the repo is fully self-contained and well-documented, it works as:
- A training asset for new hires  
- A demonstration tool for internal workshops  
- A reproducible environment for teaching Terraform, FluxCD, Helm, and monitoring

---

## License

MIT © Architected by [Sergei Denisenko](https://github.com/geeone)
