#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting security stack deployment...${NC}"

# Create namespaces
echo -e "${YELLOW}Creating namespaces...${NC}"
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace security --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace falco --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace trivy-system --dry-run=client -o yaml | kubectl apply -f -

# Label namespaces with Pod Security Standards
echo -e "${YELLOW}Applying Pod Security Standards...${NC}"
kubectl apply -f ../02-pod-security/pss-baseline.yaml

# Deploy Network Policies
echo -e "${YELLOW}Deploying network policies...${NC}"
kubectl apply -f ../01-network-policies/cilium-policies.yaml
kubectl apply -f ../01-network-policies/istio-mtls.yaml

# Deploy OPA Gatekeeper
echo -e "${YELLOW}Deploying OPA Gatekeeper...${NC}"
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace \
  --set replicas=3 \
  --set auditInterval=60

# Wait for Gatekeeper to be ready
kubectl wait --for=condition=ready pod \
  -l control-plane=controller-manager \
  -n gatekeeper-system \
  --timeout=300s

# Apply OPA policies
kubectl apply -f ../03-policy-as-code/opa-gatekeeper-policies.yaml

# Deploy Kyverno
echo -e "${YELLOW}Deploying Kyverno...${NC}"
helm repo add kyverno https://kyverno.github.io/kyverno/
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --set replicaCount=3 \
  --set backgroundController.enabled=true

# Wait for Kyverno
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=kyverno \
  -n kyverno \
  --timeout=300s

# Apply Kyverno policies
kubectl apply -f ../03-policy-as-code/kyverno-policies.yaml

# Deploy Vault
echo -e "${YELLOW}Deploying HashiCorp Vault...${NC}"
helm repo add hashicorp https://helm.releases.hashicorp.com
helm upgrade --install vault hashicorp/vault \
  --namespace vault \
  --values ../04-secrets-management/vault-integration.yaml

# Deploy External Secrets Operator
echo -e "${YELLOW}Deploying External Secrets Operator...${NC}"
helm repo add external-secrets https://charts.external-secrets.io
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace

# Deploy Sealed Secrets
echo -e "${YELLOW}Deploying Sealed Secrets...${NC}"
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace sealed-secrets \
  --create-namespace

# Deploy Falco
echo -e "${YELLOW}Deploying Falco...${NC}"
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm upgrade --install falco falcosecurity/falco \
  --namespace falco \
  --set driver.kind=modern_ebpf \
  --set tty=true \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true

kubectl apply -f ../05-runtime-security/falco-rules.yaml

# Deploy Trivy Operator
echo -e "${YELLOW}Deploying Trivy Operator...${NC}"
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm upgrade --install trivy-operator aqua/trivy-operator \
  --namespace trivy-system \
  --set="trivy.ignoreUnfixed=false" \
  --set="trivy.severity=CRITICAL,HIGH,MEDIUM"

kubectl apply -f ../07-image-security/trivy-scan-policy.yaml

# Apply RBAC configurations
echo -e "${YELLOW}Applying RBAC configurations...${NC}"
kubectl apply -f ../06-rbac/production-rbac.yaml

# Deploy audit configuration
echo -e "${YELLOW}Applying audit configurations...${NC}"
kubectl apply -f ../08-compliance/audit-policy.yaml
kubectl apply -f ../08-compliance/cis-benchmark.yaml

# Apply supply chain security
echo -e "${YELLOW}Applying supply chain security...${NC}"
kubectl apply -f ../09-supply-chain/cosign-signing.yaml

echo -e "${GREEN}Security stack deployment completed!${NC}"
echo -e "${YELLOW}Running validation checks...${NC}"
./validate-security.sh
