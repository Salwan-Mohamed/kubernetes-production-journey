#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

echo -e "${GREEN}=== Security Validation Report ===${NC}\n"

# Function to check and report
check_component() {
    local name=$1
    local command=$2
    
    echo -n "Checking $name... "
    if eval $command > /dev/null 2>&1; then
        echo -e "${GREEN}âœ" PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}âœ— FAIL${NC}"
        ((FAILED++))
    fi
}

# Network Security
echo -e "${YELLOW}Network Security:${NC}"
check_component "Cilium Network Policies" "kubectl get ciliumnetworkpolicies -A"
check_component "Istio mTLS" "kubectl get peerauthentication -A"

# Pod Security
echo -e "\n${YELLOW}Pod Security:${NC}"
check_component "PSS Labels on Production" "kubectl get namespace production -o jsonpath='{.metadata.labels.pod-security\\.kubernetes\\.io/enforce}' | grep -q restricted"
check_component "Secure Pod Templates" "kubectl get deployment -n production -o yaml | grep -q 'runAsNonRoot: true'"

# Policy Enforcement
echo -e "\n${YELLOW}Policy Enforcement:${NC}"
check_component "OPA Gatekeeper" "kubectl get pods -n gatekeeper-system -l control-plane=controller-manager --field-selector=status.phase=Running"
check_component "Kyverno" "kubectl get pods -n kyverno -l app.kubernetes.io/instance=kyverno --field-selector=status.phase=Running"
check_component "Policy Constraints" "kubectl get constraints"

# Secrets Management
echo -e "\n${YELLOW}Secrets Management:${NC}"
check_component "Vault" "kubectl get pods -n vault -l app.kubernetes.io/name=vault --field-selector=status.phase=Running"
check_component "External Secrets Operator" "kubectl get pods -n external-secrets --field-selector=status.phase=Running"
check_component "Sealed Secrets" "kubectl get pods -n sealed-secrets --field-selector=status.phase=Running"

# Runtime Security
echo -e "\n${YELLOW}Runtime Security:${NC}"
check_component "Falco DaemonSet" "kubectl get daemonset falco -n falco"
check_component "Falco Rules" "kubectl get configmap falco-rules -n falco"

# Image Security
echo -e "\n${YELLOW}Image Security:${NC}"
check_component "Trivy Operator" "kubectl get pods -n trivy-system --field-selector=status.phase=Running"
check_component "Vulnerability Reports" "kubectl get vulnerabilityreports -A"

# RBAC
echo -e "\n${YELLOW}Access Control:${NC}"
check_component "Production RBAC" "kubectl get roles -n production"
check_component "ClusterRoles" "kubectl get clusterroles | grep -E '(developer|devops|sre)'"
check_component "ServiceAccounts" "kubectl get sa -n production"

# Compliance
echo_e "\n${YELLOW}Compliance & Audit:${NC}"
check_component "Audit Policy" "kubectl get configmap audit-policy -n kube-system 2>/dev/null || echo 'Check API server configuration'"
check_component "Polaris Configuration" "kubectl get configmap polaris-config -n security"

# Supply Chain
echo -e "\n${YELLOW}Supply Chain Security:${NC}"
check_component "Cosign Configuration" "kubectl get configmap cosign-config -n cicd"
check_component "Image Verification Policies" "kubectl get clusterpolicy verify-image-signature-cosign"

# Summary
echo -e "\n${GREEN}=== Validation Summary ===${NC}"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

TOTAL=$((PASSED + FAILED))
SCORE=$((PASSED * 100 / TOTAL))

echo -e "\nSecurity Score: $SCORE%"

if [ $SCORE -ge 90 ]; then
    echo -e "${GREEN}âœ" Excellent! Your cluster meets production security standards.${NC}"
    exit 0
elif [ $SCORE -ge 75 ]; then
    echo -e "${YELLOW}âš  Good, but some improvements needed.${NC}"
    exit 0
else
    echo -e "${RED}âœ— Critical issues found. Address failures before production deployment.${NC}"
    exit 1
fi
