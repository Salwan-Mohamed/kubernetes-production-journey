# Infrastructure Provisioning: Building the Foundation for Day 1 Success

## The $180,000 Typo

It was 11:47 PM on deployment night. Sarah, a senior platform engineer at a rapidly growing fintech startup, was three hours into what should have been a routine infrastructure provisioning. Everything had gone smoothly—VPCs created, subnets configured, security groups in place. She was ready to provision the EKS cluster.

Then she ran `terraform apply`.

The terminal flickered with resource creation logs. EC2 instances spinning up. Auto-scaling groups forming. Everything looked perfect until she noticed something odd in the instance type column:

**`m5.24xlarge`** 

Her heart stopped. The Terraform variable should have been `m5.2xlarge` (8 vCPU, 32GB RAM). Instead, it was provisioning `m5.24xlarge` (96 vCPU, 384GB RAM)—**twelve times larger**.

Across three regions. Across six availability zones. Across 45 worker nodes.

**That single missing period was costing $6.12 per hour per instance—$275 per hour total—$6,600 per day.**

By the time she caught it, 12 instances were already running. The mistake cost the company $180,000 in unnecessary cloud spend over the next month.

**Infrastructure provisioning isn't just about making things work. It's about making things work correctly, efficiently, and sustainably from minute one.**

---

## Why Infrastructure Provisioning Makes or Breaks Day 1

If Day 1 is the first day of production operations, infrastructure provisioning is **Day 0.5**—the critical bridge between planning and execution.

Get this right, and everything else becomes easier. Get it wrong, and you'll spend Day 1 firefighting infrastructure issues instead of deploying applications.

### The Infrastructure Pyramid

**At the top:** Applications (what users see)  
**In the middle:** Kubernetes control plane (what developers use)  
**At the bottom:** Infrastructure (what you're building NOW)  

**Everything above depends on the foundation being solid.**

---

## The Multi-Region Financial Platform: Our Real-World Example

Throughout this article, we'll follow **"PayFlow"** (name changed), a payment processing platform handling $50M in daily transactions.

### The Requirements

**Business requirements:**
- **99.99% uptime** ($500K per hour of downtime)
- **Sub-200ms API latency** globally
- **PCI-DSS compliance**
- **Multi-region disaster recovery** (RTO: 15 minutes, RPO: 5 minutes)
- **Handle 5,000 TPS** at peak

**Technical constraints:**
- **Three cloud regions** (US-East, US-West, EU-West)
- **Hybrid connectivity** to on-premises HSM
- **100+ microservices** (starting with 15)
- **7 PostgreSQL databases**
- **6 weeks to production**

---

## Phase 1: Pre-Provisioning Validation

Before provisioning anything, validate that you **can** provision.

### The Pre-Flight Checklist

```bash
#!/bin/bash
# pre-flight-check.sh

echo "🔍 Day 1 Infrastructure Pre-Flight Check"
echo "========================================"

# 1. Cloud Provider Authentication
echo "✓ Checking AWS authentication..."
aws sts get-caller-identity

# 2. Terraform Version
echo "✓ Checking Terraform version..."
terraform version

# 3. Service Quotas
echo "✓ Checking AWS service quotas..."
aws service-quotas get-service-quota \
    --service-code vpc \
    --quota-code L-F678F1CE

# 4. DNS Zone Validation
echo "✓ Checking Route53 hosted zones..."
aws route53 list-hosted-zones-by-name --dns-name payflow.example.com

# 5. Container Registry Access
echo "✓ Checking ECR repository access..."
aws ecr describe-repositories --repository-names payflow-apps

# 6. Secrets Manager
echo "✓ Checking Secrets Manager..."
aws secretsmanager list-secrets

echo "✅ Pre-flight check complete!"
```

### Real-World Lesson: The Quota Crisis

At PayFlow, we ran the pre-flight check on Wednesday—three days before provisioning.

**The problem:** AWS default quota was **5 VPCs per region**. We needed **9 VPCs** total (3 regions × 3 VPCs each).

**The fix:** Submitted quota increase Wednesday. Approved Friday—**just in time**.

**If we hadn't run pre-flight checks?** We would have hit quota limits mid-provisioning Saturday night.

---

## Phase 2: Network Foundation

### The Three-Region Network Architecture

**Layer 1: Transit Gateway (Cross-Region Hub)**
- Central routing point for all three regions
- Enables any-to-any regional communication
- Cost: ~$50/month per attachment

**Layer 2: Regional VPCs**
- US-EAST-1: 10.0.0.0/16 (65,536 IPs)
- US-WEST-2: 10.1.0.0/16 (65,536 IPs)
- EU-WEST-1: 10.2.0.0/16 (65,536 IPs)

**Layer 3: Availability Zone Subnets**
Each region has 3 AZs, each with:
- Public subnet (/24 = 256 IPs) - load balancers, NAT gateways
- Private subnet (/20 = 4,096 IPs) - Kubernetes nodes
- Database subnet (/24 = 256 IPs) - isolated RDS

### IP Addressing Strategy

```
VPC CIDR: 10.0.0.0/16 (65,536 addresses)
├── Public Subnets: 10.0.0.0/20 (4,096)
│   ├── AZ-A: 10.0.0.0/22 (1,024)
│   ├── AZ-B: 10.0.4.0/22 (1,024)
│   └── AZ-C: 10.0.8.0/22 (1,024)
├── Private Subnets: 10.0.16.0/19 (8,192)
│   ├── AZ-A: 10.0.16.0/21 (2,048)
│   ├── AZ-B: 10.0.24.0/21 (2,048)
│   └── AZ-C: 10.0.32.0/21 (2,048)
└── Database Subnets: 10.0.48.0/22 (1,024)
    ├── AZ-A: 10.0.48.0/24 (256)
    ├── AZ-B: 10.0.49.0/24 (256)
    └── AZ-C: 10.0.50.0/24 (256)

Kubernetes Service CIDR: 172.20.0.0/16
Kubernetes Pod CIDR: 100.64.0.0/16
```

### Terraform Network Module

```hcl
# modules/network/main.tf

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Secondary CIDR for pod IPs
resource "aws_vpc_ipv4_cidr_block_association" "pods" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "100.64.0.0/16"
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 6, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.environment}-public-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# NAT Gateways (one per AZ for high availability)
resource "aws_nat_gateway" "main" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
}
```

### Real-World Lesson: The NAT Gateway Bottleneck

**The Problem:** We initially deployed a **single NAT Gateway** to save costs ($45/month).

On Day 1, API response times spiked:
- P95 latency: 2,400ms (disaster)
- P99 latency: 8,000ms (apocalypse)

**The Root Cause:** All outbound traffic funneled through one NAT Gateway. Hit connection tracking limits.

**The Fix:** One NAT Gateway per AZ. Cost: $135/month.

**Results:**
- P95 latency: 220ms
- P99 latency: 450ms

---

## Phase 3: EKS Cluster Provisioning

### Cluster Design Decisions

**Kubernetes Version:** 1.30 (one behind latest for stability)

**Node Strategy:**

| Node Type | Instance | vCPU | RAM | Use Case |
|-----------|----------|------|-----|----------|
| Core System | m6i.2xlarge | 8 | 32GB | System pods |
| General App | m6i.4xlarge | 16 | 64GB | Microservices |
| Memory-Intensive | r6i.2xlarge | 8 | 64GB | Cache, sessions |
| Spot Batch | m6i.large | 2 | 8GB | Background jobs |

### EKS Terraform Configuration

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.21"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Encryption for etcd
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # Managed node groups
  eks_managed_node_groups = {
    core-system = {
      instance_types = ["m6i.2xlarge"]
      capacity_type  = "ON_DEMAND"
      min_size       = 3
      max_size       = 6
      desired_size   = 3

      labels = {
        role = "core-system"
      }

      taints = [{
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NoSchedule"
      }]
    }
  }
}
```

### Karpenter for Dynamic Scaling

```yaml
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["spot", "on-demand"]
    - key: node.kubernetes.io/instance-type
      operator: In
      values:
        - m6i.large
        - m6i.xlarge
        - m6i.2xlarge

  limits:
    resources:
      cpu: "1000"
      memory: "1000Gi"

  consolidation:
    enabled: true

  ttlSecondsAfterEmpty: 30
```

**PayFlow Results with Karpenter:**
- 37% reduction in compute costs
- 89% of batch workloads on spot instances
- Average scaling time: 48 seconds

---

## Phase 4: Storage Infrastructure

### Storage Classes Strategy

```yaml
# 1. General Purpose (default)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true

---
# 2. High Performance (databases)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: io2-high-perf
provisioner: ebs.csi.aws.com
parameters:
  type: io2
  iops: "32000"
  encrypted: "true"
reclaimPolicy: Retain
```

### Real-World Lesson: The IOPS Crisis

**The Problem:** PostgreSQL was slow. Queries taking 2-3 seconds instead of 50ms.

**Investigation:** Volume hitting IOPS limit (3,000 IOPS on gp3) during peak hours.

**Fix:** Migrated to io2 with 20,000 IOPS.

**Results:**
- Query P99 latency: 2,800ms → 120ms
- Database CPU: 75% → 22%
- Cost increase: $120/month
- Revenue protected: $500K/hour downtime avoided

---

## Phase 5: Validation Before Proceeding

### Infrastructure Health Checks

```bash
#!/bin/bash
# validate-infrastructure.sh

echo "🔍 Infrastructure Validation"

# 1. Cluster API access
kubectl cluster-info
kubectl get nodes

# 2. Node health
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
READY_COUNT=$(kubectl get nodes --no-headers | grep -c " Ready ")

if [ "$NODE_COUNT" -eq "$READY_COUNT" ]; then
    echo "✅ All nodes ready"
else
    echo "❌ Some nodes not ready!"
    exit 1
fi

# 3. System pods
kubectl get pods -n kube-system

# 4. Test PVC creation
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Wait for PVC to bind
for i in {1..30}; do
    STATUS=$(kubectl get pvc test-pvc -o jsonpath='{.status.phase}')
    if [ "$STATUS" = "Bound" ]; then
        echo "✅ PVC test successful"
        kubectl delete pvc test-pvc
        break
    fi
    sleep 2
done

echo "✅ Validation complete!"
```

---

## The Infrastructure Checklist

**✅ Network Foundation**
- [ ] VPCs provisioned in all regions
- [ ] Subnets created across all AZs
- [ ] NAT Gateways deployed (one per AZ)
- [ ] Transit Gateway connections established
- [ ] Security groups configured

**✅ Kubernetes Cluster**
- [ ] Control plane healthy
- [ ] Worker nodes ready
- [ ] System pods running
- [ ] RBAC configured
- [ ] Autoscaler deployed

**✅ Storage**
- [ ] Storage classes created
- [ ] Default storage class set
- [ ] EBS CSI driver working
- [ ] Test PVC successful

**✅ Security**
- [ ] etcd encryption enabled
- [ ] Secrets encrypted with KMS
- [ ] Network policies ready
- [ ] IMDSv2 enforced

---

## Real-World Results: PayFlow's Infrastructure

**Timeline:**
- Planning & validation: 5 days
- Terraform development: 8 days
- Provisioning execution: 4 hours
- Validation: 2 hours
- **Total execution day: 6 hours**

**Costs:**
- Monthly infrastructure: $8,084
- Optimization target: $6,500
- Actual first month: $7,200

**Success Metrics:**
- Zero unplanned downtime
- All validation tests passed
- Ready 2 hours ahead of schedule

---

## Common Infrastructure Mistakes

### Mistake #1: Single NAT Gateway
**Fix:** One per AZ ($135/month vs $45, worth it)

### Mistake #2: Insufficient IP Space
**Fix:** Oversize CIDR blocks (use /16 for VPC)

### Mistake #3: No Resource Reservations
**Fix:** Set `--kube-reserved` and `--system-reserved`

### Mistake #4: Undersized Storage IOPS
**Fix:** Provision sufficient IOPS (io2 for production DBs)

### Mistake #5: No Validation
**Fix:** Run comprehensive validation before declaring success

---

## What's Next

You now have production-grade Kubernetes infrastructure. The foundation is solid.

**But you're not done yet.**

In the next article, we'll cover:

**Part 3: Code Deployment & CI/CD Activation**
- GitOps repository structure
- ArgoCD multi-cluster configuration
- GitHub Actions pipelines
- Progressive delivery with Argo Rollouts
- Rollback procedures that work
- Health probes that prevent bad deployments

---

## Key Takeaways

1. **Pre-flight validation saves Day 1** - Check quotas and permissions before execution
2. **Network architecture determines success** - NAT per AZ, proper CIDR planning
3. **Storage performance matters** - Don't under-provision IOPS
4. **Everything as Code** - No manual changes
5. **Validation before progression** - Test everything
6. **Cost awareness from Day 1** - Tag everything, know your burn rate

---

*Next: **Part 3 - Code Deployment & CI/CD Activation***

**About the Author:**  
Platform Engineering Lead with 5+ years architecting production Kubernetes platforms. Provisioned 50+ clusters. Still learning why NAT Gateways are always the bottleneck.
