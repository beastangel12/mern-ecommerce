# MERN E-Commerce DevOps Lab and Deployment Runbook

## Scope and architecture

The repository supplied with this task contained the application README and environment examples, but no separate infrastructure or deployment guide. This runbook records the assumptions used here.

The repeatable lab consists of three Ubuntu 22.04 VMs: one kubeadm control plane and two workers. Kubernetes runs the frontend, five initial backend replicas (with an HPA range of 5–10), MongoDB, Redis, Prometheus, Grafana, Node Exporter, Alertmanager, and a nightly backup CronJob. Jenkins builds and pushes separate frontend and backend images to Docker Hub, then deploys the `staging` branch to a configured Kubernetes cluster. Terraform can create the same three-node shape in AWS; Vagrant is the local option.

```mermaid
flowchart LR
  Dev[Git staging branch] --> Jenkins[Jenkins pipeline]
  Jenkins --> Hub[Docker Hub images]
  Jenkins --> K8s[Kubernetes cluster]
  User[Browser] --> Front[Frontend Service]
  Front --> Back[Backend Service x5–10]
  Back --> Mongo[(MongoDB StatefulSet)]
  Back --> Redis[(Redis)]
  Cron[22:00 backup CronJob] --> Mongo
  Cron --> Backup[(Local backup PVC)]
  Nodes[Ubuntu VM nodes] --> Exporter[Node Exporter DaemonSet]
  Exporter --> Prom[Prometheus + CPU/RAM rules]
  Prom --> Alert[Alertmanager email]
  Prom --> Grafana[Grafana dashboard]
```

## Local app with Docker Compose

1. Install Docker Desktop with Compose support.
2. From the repository root, copy `compose.env.example` to `.env` and set strong JWT secrets and valid Stripe values. Set Cloudinary values if using image uploads. The `.env` file is ignored by Git.
3. Start the stack with `docker compose up --build -d` or `npm run docker:up`.
4. Open `http://localhost:8080`; check logs with `docker compose logs -f backend` and stop with `docker compose down`.

Compose persists MongoDB and Redis in named volumes. `docker compose down -v` deletes those volumes and their data; only use it when you intend to reset the local database.

## Create the kubeadm lab with Vagrant and Ansible

Use a Linux/WSL host with VirtualBox, Vagrant, Ansible, Git, and internet access. The three VMs need about 7 GB RAM in total and two virtual CPUs each. For a Windows laptop, run the Ansible commands in WSL from the repository directory mounted under `/mnt/c/...`.

```bash
vagrant up
ansible -i ansible/inventory.ini k8s_cluster -m ping
ansible-playbook -i ansible/inventory.ini ansible/kubeadm.yml
```

The playbook disables swap, configures containerd and Kubernetes packages, initializes the control plane, installs Flannel, local-path PVC storage, and Metrics Server, then joins both workers. Kubernetes package minor version is set in `ansible/kubeadm.yml`; current install guidance uses the version-specific `pkgs.k8s.io` repository and matching kubeadm, kubelet, and kubectl versions ([Kubernetes kubeadm installation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)). Metrics Server 0.9 supports Kubernetes 1.34 and newer per its [official compatibility matrix](https://github.com/kubernetes-sigs/metrics-server#compatibility-matrix). The playbook enables `--kubelet-insecure-tls` because lab kubelets use self-signed certificates; use valid kubelet serving certificates in a real cluster. The local-path provisioner is for a single-machine lab and uses node-local disks ([upstream project](https://github.com/rancher/local-path-provisioner)).

Verify the cluster:

```bash
vagrant ssh k8s-control -c 'kubectl get nodes -o wide'
vagrant ssh k8s-control -c 'kubectl get pods -A'
```

To stop the VMs while retaining their disks, use `vagrant halt`. `vagrant destroy` deletes the VMs and their local data, including the lab MongoDB and backup PVCs.

## Optional AWS VMs with Terraform

Terraform provisions a VPC, public subnet, security group, and three encrypted Ubuntu 22.04 EC2 instances. It does not run Ansible or create a managed production Kubernetes service. AWS charges for running instances, disks, and network use.

1. Configure AWS credentials through the standard AWS CLI environment/profile and create an EC2 key pair.
2. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars`. Set `ssh_key_name`, your own public IP as `admin_cidr` (CIDR `/32`), and a suitable region/type.
3. From `terraform/`, run `terraform init`, inspect `terraform plan`, then `terraform apply`.
4. Use `terraform output -json node_addresses` to create an Ansible inventory. SSH to each `public_ip` but set `ansible_host` to that address and `kube_control_plane_ip` to the control plane's `private_ip`; worker nodes join over the private subnet. Use `ansible_user=ubuntu` and your EC2 key file. The committed inventory contains only fixed Vagrant IPs and must not be used for AWS.
5. Run the Ansible playbook against that generated inventory. Restrict SSH and Kubernetes API access to your IP; the demo frontend NodePort 30080 is open publicly.
6. Run `terraform destroy` when the lab is no longer needed to stop AWS charges.

This public-subnet topology is a learning setup, not a hardened production design. A production deployment should use private subnets, a managed ingress/load balancer with TLS, restricted egress, secrets management, multi-zone nodes, and durable cloud storage.

## Secrets and first Kubernetes deployment

Create secrets out of band; never commit populated secret manifests. Create namespace and app secrets from a private env file (ensure it is excluded from backups and Git):

```bash
kubectl apply -f k8s/namespace.yaml
kubectl -n mern-ecommerce create secret generic mern-ecommerce-secrets \
  --from-literal=ACCESS_TOKEN_SECRET='...' \
  --from-literal=REFRESH_TOKEN_SECRET='...' \
  --from-literal=MONGO_USER='mernapp' \
  --from-literal=MONGO_PASSWORD='...' \
  --from-literal=MONGO_URI='mongodb://mernapp:URL_ENCODED_PASSWORD@mongo:27017/mern-ecommerce?authSource=admin' \
  --from-literal=UPSTASH_REDIS_URL='redis://redis:6379' \
  --from-literal=STRIPE_SECRET_KEY='...' \
  --from-literal=CLOUDINARY_CLOUD_NAME='...' \
  --from-literal=CLOUDINARY_API_KEY='...' \
  --from-literal=CLOUDINARY_API_SECRET='...'
```

For production, set `MONGO_URI` and `UPSTASH_REDIS_URL` to managed/external services. Avoid entering secrets directly in shell history on shared systems; use a protected secret manager or a temporary env file and delete it afterward. Mongo passwords used in the URI should be URL-safe or percent-encoded.

Create the initial staging images and deploy the application manifests:

```bash
docker build -t DOCKERHUB_USER/mern-ecommerce-backend:staging ./backend
docker build --build-arg VITE_STRIPE_PUBLISHABLE_KEY='...' -t DOCKERHUB_USER/mern-ecommerce-frontend:staging ./frontend
docker push DOCKERHUB_USER/mern-ecommerce-backend:staging
docker push DOCKERHUB_USER/mern-ecommerce-frontend:staging
```

Replace `dockerhub_user` in the image fields in `k8s/backend.yaml`, `k8s/frontend.yaml`, and `k8s/backup.yaml`, then:

```bash
kubectl apply -f k8s/config.yaml
kubectl apply -f k8s/mongo.yaml
kubectl apply -f k8s/redis.yaml
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml
kubectl apply -f k8s/backup.yaml
kubectl -n mern-ecommerce get pods,svc,hpa
```

The frontend is exposed on port 30080. On the Vagrant host, open `http://localhost:8080`; on AWS, use `http://<control-plane-public-ip>:30080`. HPA requires Metrics Server and enough cluster capacity. HPA controls backend replicas from five to ten; the three-node lab is small and may not have enough CPU/RAM to schedule ten busy pods.

## Jenkins CI/CD and Docker Hub

Use a Jenkins multibranch pipeline for the target Git repository and point it at this `Jenkinsfile`. Configure a Linux agent with Docker Engine/BuildKit, `kubectl`, network access to Docker Hub and the cluster API, and the Kubernetes pipeline requirements. Add these Jenkins credentials:

| Credential ID | Type | Purpose |
| --- | --- | --- |
| `dockerhub-creds` | Username with password/token | Push images; images should be public unless an image pull secret is configured |
| `stripe-publishable-key` | Secret text | Embed the browser-safe Stripe publishable key in the frontend build |
| `staging-kubeconfig` | Secret file | Access only the staging cluster and namespace |

The pipeline runs only for branch `staging` and pushes a build-number tag and mutable `staging` tag. Its default `DEPLOY_TARGET` is `staging`. Selecting `production` requires an approval step and the separate `production-kubeconfig` Jenkins file credential. Production also requires a precreated `production/mern-ecommerce-secrets` Secret containing `ACCESS_TOKEN_SECRET`, `REFRESH_TOKEN_SECRET`, `MONGO_URI` (managed/external MongoDB), `UPSTASH_REDIS_URL` (managed/external Redis), Stripe, and Cloudinary keys. Before first production release, change `https://shop.example.com` in `k8s/production/kustomization.yaml` to the real browser URL and configure TLS on the cloud load balancer. The production overlay does not install MongoDB/Redis inside the cluster. Create the app Secret before the first staging run too. Restrict each Jenkins kubeconfig RBAC to only its deployment namespace. Docker Hub and Kubernetes credentials are intentionally not present in this repository.

## Daily database and backend backup

`k8s/backup.yaml` schedules the database dump and backend image filesystem archive at 22:00 Asia/Kathmandu time. It compresses the MongoDB dump, stores both archives on a 20 GiB local-path PVC, and deletes files older than 14 days. Check that it ran with:

```bash
kubectl -n mern-ecommerce get cronjobs,jobs,pvc
kubectl -n mern-ecommerce logs job/<backup-job-name>
```

The lab PVC is node-local and is not disaster recovery. For production, send encrypted copies to an off-cluster object store, monitor backup job success, test restores regularly, and use a durable CSI volume or managed MongoDB backups.

## Full MongoDB migration

The migration script dumps the complete source database to a timestamped gzip archive, then restores it to the target with `mongorestore --drop` (matching target collections are replaced). It refuses to run without an explicit confirmation and a separate source and target URI. Install MongoDB Database Tools and set protected shell environment variables:

```bash
export SOURCE_MONGO_URI='mongodb+srv://.../mern-ecommerce?retryWrites=true&w=majority'
export TARGET_MONGO_URI='mongodb+srv://.../mern-ecommerce?retryWrites=true&w=majority'
export CONFIRM_TARGET_REPLACE=YES
bash scripts/migrate-mongo.sh
```

Take and retain an independent target backup before migration, quiesce writes or plan a final delta/cutover, then verify document counts and application reads before directing production traffic. The actual migration has not been run because source/target database URIs and a cutover window were not provided.

## Prometheus, Node Exporter, Grafana, and email alerts

Prometheus stores scraped metrics as time series and evaluates alert rules; Grafana queries Prometheus for dashboards. The repository includes a node discovery scrape config, a Node Exporter DaemonSet, CPU/RAM rules, Alertmanager email routing, and a provisioned Grafana Node Exporter dashboard. See the official [Prometheus overview](https://prometheus.io/docs/introduction/overview/) and [Grafana Ubuntu installation documentation](https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian/).

Create the alert and dashboard credentials before applying the manifests:

```bash
kubectl apply -f k8s/monitoring/namespace.yaml
kubectl -n monitoring create secret generic alertmanager-config --from-file=alertmanager.yml=/secure/path/alertmanager.yml
kubectl -n monitoring create secret generic grafana-admin --from-literal=password='use-a-unique-long-password'
kubectl apply -f k8s/monitoring/node-exporter.yaml
kubectl apply -f k8s/monitoring/prometheus.yaml
kubectl apply -f k8s/monitoring/alertmanager.yaml
kubectl apply -f k8s/monitoring/grafana.yaml
```

Use `k8s/monitoring/alertmanager-secret.example.yaml` as the starting config, replacing the example SMTP host, sender, app password, and recipient before storing it in a protected file. The Grafana Node Exporter dashboard is provisioned automatically. On the Vagrant host, Grafana is available at `http://localhost:30300` (admin plus the password stored in the Secret). Prometheus can be inspected with `kubectl -n monitoring port-forward svc/prometheus 9090:9090`.

CPU alert threshold is over 80% for five minutes; memory is over 85% for five minutes. Tune those thresholds and SMTP settings to the target fleet. Do not expose Prometheus or Grafana publicly without authentication, TLS, and network restrictions.

## Production release and rollback

The production overlay and gated Jenkins stage provide a deployment path, but require real cloud resources and values before the first release. It keeps the NodePort frontend; configure a TLS load balancer or ingress in front of the cluster and direct traffic to port 30080. Also configure managed MongoDB/Redis, scheduled off-cluster database backups, private networking, resource sizing from load tests, immutable image digests, security scanning, and secret management. The lab backup CronJob stores archives only on its local-path PVC; it is intentionally excluded from the production overlay. Roll back an application deployment with `kubectl -n <namespace> rollout undo deployment/backend` or the corresponding frontend deployment; database restore/cutover must follow a separately reviewed recovery plan.
