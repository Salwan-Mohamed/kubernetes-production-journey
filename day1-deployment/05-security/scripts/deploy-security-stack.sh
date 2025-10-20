#!/bin/bash
# Complete Security Stack Deployment Script
# Part 5: Security Configuration - Kubernetes Production Journey

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
SECURITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE_PRODUCTION="production"
NAMESPACE_SECURITY="security"
NAMESPACE_VAULT="vault"
NAMESPACE_FALCO="falco"

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local required_tools=("kubectl" "helm" "cosign")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is not installed"
            exit 1
        fi
    done
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Create namespaces
create_namespaces() {
    log_info "Creating namespaces..."
    
    local namespaces=("$NAMESPACE_PRODUCTION" "$NAMESPACE_SECURITY" "$NAMESPACE_VAULT" "$NAMESPACE_FALCO" "trivy-system" "polaris")
    
    for ns in "${namespaces[@]}"; do
        kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
        log_info "Namespace $ns created/updated"
    done
}

# Deploy Pod Security Standards
deploy_pss() {
    log_info "Deploying Pod Security Standards..."
    
    kubectl apply -f "$SECURITY_DIR/02-pod-security/pss-baseline.yaml"
    
    log_info "Pod Security Standards deployed"
}

# Deploy Network Policies
deploy_network_policies() {
    log_info "Deploying Network Policies..."
    
    # Check if Cilium is installed
    if kubectl get pods -n kube-system -l k8s-app=cilium &> /dev/null; then
        log_info "Cilium detected, deploying Cilium Network Policies..."
        kubectl apply -f "$SECURITY_DIR/01-network-policies/cilium-policies.yaml"
    else
        log_warn "Cilium not detected, skipping Cilium policies"
    fi
    
    # Check if Istio is installed
    if kubectl get pods -n istio-system &> /dev/null; then
        log_info "Istio detected, deploying mTLS policies..."
        kubectl apply -f "$SECURITY_DIR/01-network-policies/istio-mtls.yaml"
    else
        log_warn "Istio not detected, skipping Istio mTLS policies"
    fi
    
    log_info "Network Policies deployed"
}

# Deploy OPA Gatekeeper
deploy_opa_gatekeeper() {
    log_info "Deploying OPA Gatekeeper..."
    
    # Install Gatekeeper via Helm
    helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
    helm repo update
    
    helm upgrade --install gatekeeper gatekeeper/gatekeeper \
        --namespace gatekeeper-system \
        --create-namespace \
        --set replicas=3 \
        --set auditInterval=60 \
        --wait
    
    # Wait for Gatekeeper to be ready
    kubectl wait --for=condition=Ready pods --all -n gatekeeper-system --timeout=300s
    
    # Apply constraint templates and constraints
    sleep 10  # Wait for CRDs to be fully registered
    kubectl apply -f "$SECURITY_DIR/03-policy-as-code/opa-gatekeeper-policies.yaml"
    
    log_info "OPA Gatekeeper deployed"
}

# Deploy Kyverno
deploy_kyverno() {
    log_info "Deploying Kyverno..."
    
    helm repo add kyverno https://kyverno.github.io/kyverno/
    helm repo update
    
    helm upgrade --install kyverno kyverno/kyverno \
        --namespace kyverno \
        --create-namespace \
        --set replicaCount=3 \
        --set admissionController.replicas=3 \
        --wait
    
    # Wait for Kyverno to be ready
    kubectl wait --for=condition=Ready pods --all -n kyverno --timeout=300s
    
    # Apply policies
    sleep 10
    kubectl apply -f "$SECURITY_DIR/03-policy-as-code/kyverno-policies.yaml"
    
    log_info "Kyverno deployed"
}

# Deploy HashiCorp Vault
deploy_vault() {
    log_info "Deploying HashiCorp Vault..."
    
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
    
    # Apply Vault configuration
    kubectl apply -f "$SECURITY_DIR/04-secrets-management/vault-integration.yaml"
    
    # Install Vault using Helm with values from ConfigMap
    helm upgrade --install vault hashicorp/vault \
        --namespace "$NAMESPACE_VAULT" \
        --create-namespace \
        --values <(kubectl get configmap vault-helm-values -n "$NAMESPACE_VAULT" -o jsonpath='{.data.values\.yaml}') \
        --wait
    
    log_info "Vault deployed (requires manual initialization)"
    log_warn "Run 'kubectl exec -n vault vault-0 -- vault operator init' to initialize Vault"
}

# Deploy External Secrets Operator
deploy_external_secrets() {
    log_info "Deploying External Secrets Operator..."
    
    helm repo add external-secrets https://charts.external-secrets.io
    helm repo update
    
    helm upgrade --install external-secrets external-secrets/external-secrets \
        --namespace external-secrets-system \
        --create-namespace \
        --set installCRDs=true \
        --wait
    
    log_info "External Secrets Operator deployed"
}

# Deploy Sealed Secrets
deploy_sealed_secrets() {
    log_info "Deploying Sealed Secrets..."
    
    kubectl apply -f "$SECURITY_DIR/04-secrets-management/sealed-secrets.yaml"
    
    helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
    helm repo update
    
    helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
        --namespace sealed-secrets \
        --create-namespace \
        --wait
    
    log_info "Sealed Secrets deployed"
}

# Deploy Falco
deploy_falco() {
    log_info "Deploying Falco..."
    
    helm repo add falcosecurity https://falcosecurity.github.io/charts
    helm repo update
    
    # Apply custom rules
    kubectl apply -f "$SECURITY_DIR/05-runtime-security/falco-rules.yaml"
    
    # Install Falco
    helm upgrade --install falco falcosecurity/falco \
        --namespace "$NAMESPACE_FALCO" \
        --create-namespace \
        --set driver.kind=ebpf \
        --set falco.rulesFile[0]=/etc/falco/falco_rules.yaml \
        --set falco.rulesFile[1]=/etc/falco/rules.d/custom-rules.yaml \
        --wait
    
    # Deploy Falcosidekick
    kubectl apply -f "$SECURITY_DIR/05-runtime-security/falco-rules.yaml"
    
    log_info "Falco deployed"
}

# Deploy Trivy Operator
deploy_trivy() {
    log_info "Deploying Trivy Operator..."
    
    helm repo add aqua https://aquasecurity.github.io/helm-charts/
    helm repo update
    
    helm upgrade --install trivy-operator aqua/trivy-operator \
        --namespace trivy-system \
        --create-namespace \
        --set="trivy.ignoreUnfixed=false" \
        --wait
    
    # Apply configuration
    kubectl apply -f "$SECURITY_DIR/07-image-security/trivy-operator.yaml"
    
    log_info "Trivy Operator deployed"
}

# Deploy RBAC configurations
deploy_rbac() {
    log_info "Deploying RBAC configurations..."
    
    kubectl apply -f "$SECURITY_DIR/06-rbac/production-rbac.yaml"
    
    log_info "RBAC configurations deployed"
}

# Deploy Image Security policies
deploy_image_security() {
    log_info "Deploying Image Security policies..."
    
    kubectl apply -f "$SECURITY_DIR/07-image-security/image-policy.yaml"
    
    log_info "Image Security policies deployed"
}

# Deploy Compliance configurations
deploy_compliance() {
    log_info "Deploying Compliance configurations..."
    
    # Apply audit policy (requires API server reconfiguration)
    log_warn "Audit policy requires API server configuration"
    log_warn "Copy $SECURITY_DIR/08-compliance/audit-policy.yaml to control plane"
    
    # Deploy CIS Benchmark
    kubectl apply -f "$SECURITY_DIR/08-compliance/cis-benchmark.yaml"
    
    # Deploy Polaris
    helm repo add fairwinds-stable https://charts.fairwinds.com/stable
    helm repo update
    
    helm upgrade --install polaris fairwinds-stable/polaris \
        --namespace polaris \
        --create-namespace \
        --set dashboard.replicas=2 \
        --wait
    
    kubectl apply -f "$SECURITY_DIR/08-compliance/polaris-config.yaml"
    
    log_info "Compliance configurations deployed"
}

# Deploy Supply Chain Security
deploy_supply_chain() {
    log_info "Deploying Supply Chain Security..."
    
    kubectl apply -f "$SECURITY_DIR/09-supply-chain/cosign-config.yaml"
    kubectl apply -f "$SECURITY_DIR/09-supply-chain/slsa-provenance.yaml"
    
    log_info "Supply Chain Security configurations deployed"
}

# Main deployment flow
main() {
    log_info "Starting Security Stack Deployment..."
    log_info "======================================"
    
    check_prerequisites
    create_namespaces
    
    log_info ""
    log_info "Deploying security components..."
    
    deploy_pss
    deploy_network_policies
    deploy_opa_gatekeeper
    deploy_kyverno
    deploy_rbac
    deploy_vault
    deploy_external_secrets
    deploy_sealed_secrets
    deploy_falco
    deploy_trivy
    deploy_image_security
    deploy_compliance
    deploy_supply_chain
    
    log_info ""
    log_info "======================================"
    log_info "Security Stack Deployment Complete!"
    log_info "======================================"
    
    log_info ""
    log_info "Next steps:"
    log_info "1. Initialize Vault: kubectl exec -n vault vault-0 -- vault operator init"
    log_info "2. Run validation: ./validate-security.sh"
    log_info "3. Review CIS Benchmark results: kubectl logs -n kube-system job/cis-benchmark-scan"
    log_info "4. Access Polaris dashboard: kubectl port-forward -n polaris svc/polaris-dashboard 8080:80"
}

main "$@"
