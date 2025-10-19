#!/bin/bash
# Security Validation Script
# Part 5: Security Configuration - Kubernetes Production Journey

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${BLUE}[SUCCESS]${NC} $1"; }

VALIDATION_FAILED=0

# Validate Pod Security Standards
validate_pss() {
    log_info "Validating Pod Security Standards..."
    
    local production_pss=$(kubectl get namespace production -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')
    
    if [[ "$production_pss" == "restricted" ]]; then
        log_success "Production namespace has restricted PSS"
    else
        log_error "Production namespace does not have restricted PSS"
        VALIDATION_FAILED=1
    fi
}

# Validate Network Policies
validate_network_policies() {
    log_info "Validating Network Policies..."
    
    local np_count=$(kubectl get networkpolicies -n production --no-headers 2>/dev/null | wc -l)
    
    if [[ $np_count -gt 0 ]]; then
        log_success "Network policies found in production namespace: $np_count"
    else
        log_warn "No network policies found in production namespace"
    fi
}

# Validate OPA Gatekeeper
validate_opa() {
    log_info "Validating OPA Gatekeeper..."
    
    if kubectl get pods -n gatekeeper-system -l control-plane=controller-manager --no-headers 2>/dev/null | grep -q Running; then
        log_success "OPA Gatekeeper is running"
        
        # Check constraints
        local constraint_count=$(kubectl get constraints --all-namespaces --no-headers 2>/dev/null | wc -l)
        log_info "Active constraints: $constraint_count"
    else
        log_error "OPA Gatekeeper is not running"
        VALIDATION_FAILED=1
    fi
}

# Validate Kyverno
validate_kyverno() {
    log_info "Validating Kyverno..."
    
    if kubectl get pods -n kyverno -l app.kubernetes.io/name=kyverno --no-headers 2>/dev/null | grep -q Running; then
        log_success "Kyverno is running"
        
        # Check policies
        local policy_count=$(kubectl get clusterpolicy --no-headers 2>/dev/null | wc -l)
        log_info "Active cluster policies: $policy_count"
    else
        log_error "Kyverno is not running"
        VALIDATION_FAILED=1
    fi
}

# Validate Vault
validate_vault() {
    log_info "Validating HashiCorp Vault..."
    
    if kubectl get pods -n vault -l app.kubernetes.io/name=vault --no-headers 2>/dev/null | grep -q Running; then
        log_success "Vault is running"
        
        # Check if Vault is initialized
        local vault_status=$(kubectl exec -n vault vault-0 -- vault status -format=json 2>/dev/null | jq -r '.initialized' || echo "false")
        
        if [[ "$vault_status" == "true" ]]; then
            log_success "Vault is initialized"
        else
            log_warn "Vault is not initialized yet"
        fi
    else
        log_error "Vault is not running"
        VALIDATION_FAILED=1
    fi
}

# Validate External Secrets Operator
validate_external_secrets() {
    log_info "Validating External Secrets Operator..."
    
    if kubectl get pods -n external-secrets-system --no-headers 2>/dev/null | grep -q Running; then
        log_success "External Secrets Operator is running"
    else
        log_warn "External Secrets Operator is not running"
    fi
}

# Validate Falco
validate_falco() {
    log_info "Validating Falco..."
    
    if kubectl get pods -n falco -l app=falco --no-headers 2>/dev/null | grep -q Running; then
        log_success "Falco is running"
        
        local falco_count=$(kubectl get pods -n falco -l app=falco --no-headers | wc -l)
        log_info "Falco pods running: $falco_count"
    else
        log_error "Falco is not running"
        VALIDATION_FAILED=1
    fi
}

# Validate Trivy Operator
validate_trivy() {
    log_info "Validating Trivy Operator..."
    
    if kubectl get pods -n trivy-system --no-headers 2>/dev/null | grep -q Running; then
        log_success "Trivy Operator is running"
        
        # Check vulnerability reports
        local vuln_count=$(kubectl get vulnerabilityreports --all-namespaces --no-headers 2>/dev/null | wc -l)
        log_info "Vulnerability reports: $vuln_count"
    else
        log_error "Trivy Operator is not running"
        VALIDATION_FAILED=1
    fi
}

# Validate RBAC
validate_rbac() {
    log_info "Validating RBAC..."
    
    local clusterrole_count=$(kubectl get clusterroles --no-headers | wc -l)
    local role_count=$(kubectl get roles -n production --no-headers 2>/dev/null | wc -l)
    
    log_info "ClusterRoles: $clusterrole_count"
    log_info "Roles in production: $role_count"
    
    # Check for overly permissive bindings
    local cluster_admin_bindings=$(kubectl get clusterrolebindings -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name')
    
    if [[ -n "$cluster_admin_bindings" ]]; then
        log_warn "Cluster-admin bindings found:"
        echo "$cluster_admin_bindings" | while read binding; do
            log_warn "  - $binding"
        done
    fi
}

# Validate Image Security
validate_image_security() {
    log_info "Validating Image Security policies..."
    
    # Check for unsigned images in production
    local unsigned_count=0
    
    while IFS= read -r pod; do
        local images=$(kubectl get pod "$pod" -n production -o jsonpath='{.spec.containers[*].image}')
        for image in $images; do
            if [[ ! $image =~ @sha256: ]]; then
                log_warn "Pod $pod uses tag instead of digest: $image"
                ((unsigned_count++))
            fi
        done
    done < <(kubectl get pods -n production -o jsonpath='{.items[*].metadata.name}')
    
    if [[ $unsigned_count -eq 0 ]]; then
        log_success "All images use digests"
    else
        log_warn "Found $unsigned_count images using tags instead of digests"
    fi
}

# Test Pod Security
test_pod_security() {
    log_info "Testing Pod Security enforcement..."
    
    # Try to create a privileged pod (should fail)
    cat <<EOF | kubectl apply -f - 2>&1 | grep -q "violates PodSecurity" && log_success "Privileged pods are blocked" || log_error "Privileged pods are NOT blocked"
apiVersion: v1
kind: Pod
metadata:
  name: privileged-test
  namespace: production
spec:
  containers:
  - name: test
    image: nginx
    securityContext:
      privileged: true
EOF
    
    # Clean up
    kubectl delete pod privileged-test -n production --ignore-not-found=true 2>/dev/null
}

# Run CIS Benchmark
run_cis_benchmark() {
    log_info "Running CIS Benchmark..."
    
    # Check if job exists and get results
    if kubectl get job cis-benchmark-scan -n kube-system &>/dev/null; then
        local job_status=$(kubectl get job cis-benchmark-scan -n kube-system -o jsonpath='{.status.succeeded}')
        
        if [[ "$job_status" == "1" ]]; then
            log_success "CIS Benchmark scan completed"
            log_info "View results: kubectl logs -n kube-system job/cis-benchmark-scan"
        else
            log_warn "CIS Benchmark scan not completed yet"
        fi
    else
        log_warn "CIS Benchmark job not found"
    fi
}

# Generate Security Report
generate_report() {
    log_info "Generating Security Report..."
    
    local report_file="security-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "======================================"
        echo "Kubernetes Security Validation Report"
        echo "Generated: $(date)"
        echo "======================================"
        echo ""
        echo "Cluster: $(kubectl config current-context)"
        echo "Kubernetes Version: $(kubectl version --short 2>/dev/null | grep Server | cut -d: -f2)"
        echo ""
        echo "Security Components Status:"
        echo "----------------------------"
        kubectl get pods -n gatekeeper-system -o wide 2>/dev/null || echo "OPA Gatekeeper: Not installed"
        kubectl get pods -n kyverno -o wide 2>/dev/null || echo "Kyverno: Not installed"
        kubectl get pods -n vault -o wide 2>/dev/null || echo "Vault: Not installed"
        kubectl get pods -n falco -o wide 2>/dev/null || echo "Falco: Not installed"
        kubectl get pods -n trivy-system -o wide 2>/dev/null || echo "Trivy: Not installed"
        echo ""
        echo "Policy Summary:"
        echo "---------------"
        echo "OPA Constraints: $(kubectl get constraints --all-namespaces --no-headers 2>/dev/null | wc -l)"
        echo "Kyverno Policies: $(kubectl get clusterpolicy --no-headers 2>/dev/null | wc -l)"
        echo "Network Policies: $(kubectl get networkpolicies --all-namespaces --no-headers 2>/dev/null | wc -l)"
        echo ""
    } > "$report_file"
    
    log_success "Report saved to: $report_file"
}

# Main validation flow
main() {
    log_info "Starting Security Validation..."
    log_info "================================"
    echo ""
    
    validate_pss
    validate_network_policies
    validate_opa
    validate_kyverno
    validate_vault
    validate_external_secrets
    validate_falco
    validate_trivy
    validate_rbac
    validate_image_security
    test_pod_security
    run_cis_benchmark
    
    echo ""
    generate_report
    
    echo ""
    log_info "================================"
    
    if [[ $VALIDATION_FAILED -eq 0 ]]; then
        log_success "All critical security validations passed!"
        exit 0
    else
        log_error "Some security validations failed. Please review the output above."
        exit 1
    fi
}

main "$@"
