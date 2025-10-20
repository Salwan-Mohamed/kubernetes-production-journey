#!/bin/bash
# Security Validation Script
# Comprehensive security checks for Kubernetes cluster

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0
WARNINGS=0

echo "==========================================================="
echo "  Kubernetes Security Validation"
echo "==========================================================="
echo ""

check_pass() {
    echo -e "${GREEN}✔ PASS${NC}: $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}✘ FAIL${NC}: $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
    ((WARNINGS++))
}

# 1. Check Pod Security Standards
echo "1. Checking Pod Security Standards..."
if kubectl get ns production -o json | jq -e '.metadata.labels["pod-security.kubernetes.io/enforce"] == "restricted"' > /dev/null 2>&1; then
    check_pass "Production namespace enforces restricted PSS"
else
    check_fail "Production namespace does not enforce restricted PSS"
fi
echo ""

# 2. Check Network Policies
echo "2. Checking Network Policies..."
if kubectl get networkpolicy -n production default-deny-ingress > /dev/null 2>&1; then
    check_pass "Default deny ingress policy exists"
else
    check_fail "No default deny ingress policy found"
fi

if kubectl get networkpolicy -n production default-deny-egress > /dev/null 2>&1; then
    check_pass "Default deny egress policy exists"
else
    check_warn "No default deny egress policy found"
fi
echo ""

# 3. Check RBAC Configuration
echo "3. Checking RBAC Configuration..."
CLUSTER_ADMIN_BINDINGS=$(kubectl get clusterrolebinding -o json | \
    jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .metadata.name' | wc -l)

if [ "$CLUSTER_ADMIN_BINDINGS" -gt 5 ]; then
    check_warn "$CLUSTER_ADMIN_BINDINGS cluster-admin bindings found (consider reducing)"
else
    check_pass "Reasonable number of cluster-admin bindings ($CLUSTER_ADMIN_BINDINGS)"
fi
echo ""

# 4. Check Service Account Token Mounting
echo "4. Checking Service Account Configuration..."
AUTO_MOUNT_COUNT=$(kubectl get sa --all-namespaces -o json | \
    jq '[.items[] | select(.automountServiceAccountToken != false)] | length')

if [ "$AUTO_MOUNT_COUNT" -gt 20 ]; then
    check_warn "$AUTO_MOUNT_COUNT service accounts auto-mount tokens (consider disabling)"
else
    check_pass "Service account token auto-mounting is well-controlled"
fi
echo ""

# 5. Check for Privileged Pods
echo "5. Checking for Privileged Pods..."
PRIVILEGED_PODS=$(kubectl get pods --all-namespaces -o json | \
    jq -r '.items[] | select(.spec.containers[]?.securityContext?.privileged == true) | "\(.metadata.namespace)/\(.metadata.name)"' | wc -l)

if [ "$PRIVILEGED_PODS" -eq 0 ]; then
    check_pass "No privileged pods found"
else
    check_warn "$PRIVILEGED_PODS privileged pods found"
    kubectl get pods --all-namespaces -o json | \
        jq -r '.items[] | select(.spec.containers[]?.securityContext?.privileged == true) | "  - \(.metadata.namespace)/\(.metadata.name)"'
fi
echo ""

# 6. Check for Host Network Usage
echo "6. Checking Host Network Usage..."
HOST_NETWORK_PODS=$(kubectl get pods --all-namespaces -o json | \
    jq -r '.items[] | select(.spec.hostNetwork == true) | "\(.metadata.namespace)/\(.metadata.name)"' | wc -l)

if [ "$HOST_NETWORK_PODS" -eq 0 ]; then
    check_pass "No pods using host network"
else
    check_warn "$HOST_NETWORK_PODS pods using host network (verify if necessary)"
fi
echo ""

# 7. Check Image Pull Policies
echo "7. Checking Image Pull Policies..."
ALWAYS_PULL_COUNT=$(kubectl get pods --all-namespaces -o json | \
    jq '[.items[].spec.containers[] | select(.imagePullPolicy == "Always")] | length')

TOTAL_CONTAINERS=$(kubectl get pods --all-namespaces -o json | \
    jq '[.items[].spec.containers[]] | length')

PERCENT=$((ALWAYS_PULL_COUNT * 100 / TOTAL_CONTAINERS))

if [ "$PERCENT" -gt 70 ]; then
    check_pass "${PERCENT}% of containers use imagePullPolicy: Always"
else
    check_warn "Only ${PERCENT}% of containers use imagePullPolicy: Always"
fi
echo ""

# 8. Check Secrets Encryption
echo "8. Checking Secrets Encryption..."
if kubectl get --raw /api/v1/namespaces/kube-system/secrets/test-secret 2>&1 | grep -q "NotFound"; then
    # Create test secret
    kubectl create secret generic test-secret -n kube-system --from-literal=test=data > /dev/null 2>&1
    
    # Check if encrypted in etcd (requires etcd access)
    if command -v etcdctl > /dev/null 2>&1; then
        ENCRYPTED=$(ETCDCTL_API=3 etcdctl get /registry/secrets/kube-system/test-secret 2>&1 | grep -c "k8s:enc:aescbc" || true)
        if [ "$ENCRYPTED" -gt 0 ]; then
            check_pass "Secrets are encrypted at rest in etcd"
        else
            check_fail "Secrets are NOT encrypted at rest in etcd"
        fi
    else
        check_warn "Cannot verify etcd encryption (etcdctl not available)"
    fi
    
    kubectl delete secret test-secret -n kube-system > /dev/null 2>&1
fi
echo ""

# 9. Check Audit Logging
echo "9. Checking Audit Logging..."
if kubectl get pods -n kube-system -l component=kube-apiserver -o json | \
    jq -e '.items[0].spec.containers[0].command | any(contains("--audit-log-path"))' > /dev/null 2>&1; then
    check_pass "Audit logging is enabled"
else
    check_fail "Audit logging is not enabled"
fi
echo ""

# 10. Check Image Signatures
echo "10. Checking Image Signature Policies..."
if kubectl get clusterimagepolicy > /dev/null 2>&1; then
    POLICY_COUNT=$(kubectl get clusterimagepolicy --no-headers 2>/dev/null | wc -l)
    if [ "$POLICY_COUNT" -gt 0 ]; then
        check_pass "Image signature policies are configured ($POLICY_COUNT policies)"
    else
        check_warn "No image signature policies found"
    fi
else
    check_warn "Sigstore Policy Controller not installed"
fi
echo ""

# 11. Check Runtime Security
echo "11. Checking Runtime Security Tools..."
if kubectl get pods -n falco -l app.kubernetes.io/name=falco > /dev/null 2>&1; then
    check_pass "Falco runtime security is installed"
else
    check_warn "Falco runtime security not found"
fi
echo ""

# 12. Check Resource Limits
echo "12. Checking Resource Limits..."
NO_LIMITS=$(kubectl get pods --all-namespaces -o json | \
    jq -r '.items[] | select(.spec.containers[] | select(.resources.limits == null)) | "\(.metadata.namespace)/\(.metadata.name)"' | wc -l)

if [ "$NO_LIMITS" -eq 0 ]; then
    check_pass "All pods have resource limits defined"
else
    check_warn "$NO_LIMITS pods without resource limits"
fi
echo ""

# 13. Check Kyverno Policies
echo "13. Checking Policy Enforcement (Kyverno)..."
if kubectl get clusterpolicy > /dev/null 2>&1; then
    POLICY_COUNT=$(kubectl get clusterpolicy --no-headers 2>/dev/null | wc -l)
    if [ "$POLICY_COUNT" -gt 0 ]; then
        check_pass "Kyverno policies are configured ($POLICY_COUNT policies)"
    else
        check_warn "No Kyverno cluster policies found"
    fi
else
    check_warn "Kyverno not installed"
fi
echo ""

# Summary
echo "==========================================================="
echo "  Security Validation Summary"
echo "==========================================================="
echo -e "${GREEN}Passed:${NC}   $PASSED"
echo -e "${RED}Failed:${NC}   $FAILED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo "==========================================================="

if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}Security validation failed! Please address the failures above.${NC}"
    exit 1
elif [ "$WARNINGS" -gt 5 ]; then
    echo -e "${YELLOW}Security validation passed with warnings. Review recommended.${NC}"
    exit 0
else
    echo -e "${GREEN}Security validation passed successfully!${NC}"
    exit 0
fi
