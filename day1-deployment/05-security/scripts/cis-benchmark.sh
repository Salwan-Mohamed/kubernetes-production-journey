#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Running CIS Kubernetes Benchmark...${NC}\n"

# Create security namespace if not exists
kubectl create namespace security --dry-run=client -o yaml | kubectl apply -f -

# Apply kube-bench job
kubectl apply -f ../08-compliance/cis-benchmark.yaml

# Wait for job to complete
echo -e "${YELLOW}Waiting for kube-bench job to complete...${NC}"
kubectl wait --for=condition=complete job/kube-bench -n security --timeout=600s

# Get results
echo -e "\n${GREEN}CIS Benchmark Results:${NC}\n"
kubectl logs job/kube-bench -n security

# Save results to file
MKDIR -p ./reports
kubectl logs job/kube-bench -n security > ./reports/cis-benchmark-$(date +%Y%m%d-%H%M%S).json

echo -e "\n${GREEN}Results saved to ./reports/${NC}"

# Cleanup
kubectl delete job kube-bench -n security

echo -e "${GREEN}CIS Benchmark completed!${NC}"
