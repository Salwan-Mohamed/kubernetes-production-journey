#!/bin/bash
# CIS Kubernetes Benchmark Runner
# Part 5: Security Configuration - Kubernetes Production Journey

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Run CIS Benchmark
run_benchmark() {
    log_info "Running CIS Kubernetes Benchmark..."
    
    # Delete existing job if present
    kubectl delete job cis-benchmark-scan -n kube-system --ignore-not-found=true
    
    # Apply benchmark job
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: cis-benchmark-scan
  namespace: kube-system
spec:
  template:
    spec:
      hostPID: true
      hostNetwork: true
      serviceAccountName: cis-benchmark
      containers:
      - name: kube-bench
        image: aquasec/kube-bench:v0.7.1
        command: ["kube-bench", "run", "--targets", "node,policies,managedservices", "--json"]
        volumeMounts:
        - name: var-lib-etcd
          mountPath: /var/lib/etcd
          readOnly: true
        - name: var-lib-kubelet
          mountPath: /var/lib/kubelet
          readOnly: true
        - name: etc-systemd
          mountPath: /etc/systemd
          readOnly: true
        - name: etc-kubernetes
          mountPath: /etc/kubernetes
          readOnly: true
        - name: usr-bin
          mountPath: /usr/local/mount-from-host/bin
          readOnly: true
      restartPolicy: Never
      volumes:
      - name: var-lib-etcd
        hostPath:
          path: /var/lib/etcd
      - name: var-lib-kubelet
        hostPath:
          path: /var/lib/kubelet
      - name: etc-systemd
        hostPath:
          path: /etc/systemd
      - name: etc-kubernetes
        hostPath:
          path: /etc/kubernetes
      - name: usr-bin
        hostPath:
          path: /usr/bin
EOF
    
    log_info "Waiting for benchmark to complete..."
    kubectl wait --for=condition=complete job/cis-benchmark-scan -n kube-system --timeout=300s
    
    log_info "Benchmark completed. Fetching results..."
}

# Parse and display results
display_results() {
    local output=$(kubectl logs -n kube-system job/cis-benchmark-scan)
    
    echo "$output" > cis-benchmark-results.json
    
    log_info "Results saved to: cis-benchmark-results.json"
    
    # Parse results
    local total_pass=$(echo "$output" | jq '[.Controls[].tests[].results[] | select(.status=="PASS")] | length' 2>/dev/null || echo "0")
    local total_fail=$(echo "$output" | jq '[.Controls[].tests[].results[] | select(.status=="FAIL")] | length' 2>/dev/null || echo "0")
    local total_warn=$(echo "$output" | jq '[.Controls[].tests[].results[] | select(.status=="WARN")] | length' 2>/dev/null || echo "0")
    
    echo ""
    log_info "================================"
    log_info "CIS Benchmark Results Summary"
    log_info "================================"
    echo -e "${GREEN}PASS:${NC} $total_pass"
    echo -e "${RED}FAIL:${NC} $total_fail"
    echo -e "${YELLOW}WARN:${NC} $total_warn"
    echo ""
    
    if [[ $total_fail -gt 0 ]]; then
        log_error "Failed checks found. Review cis-benchmark-results.json for details."
        
        log_info "Top Failed Checks:"
        echo "$output" | jq -r '[.Controls[].tests[].results[] | select(.status=="FAIL")] | .[:5][] | "  \(.test_number): \(.test_desc)"' 2>/dev/null
    else
        log_info "All checks passed!"
    fi
}

# Generate remediation report
generate_remediation() {
    log_info "Generating remediation report..."
    
    local output=$(cat cis-benchmark-results.json)
    
    {
        echo "CIS Kubernetes Benchmark Remediation Guide"
        echo "=========================================="
        echo "Generated: $(date)"
        echo ""
        echo "Failed Checks and Remediation:"
        echo "------------------------------"
        
        echo "$output" | jq -r '[.Controls[].tests[].results[] | select(.status=="FAIL")] | .[] | "\nCheck: \(.test_number) - \(.test_desc)\nRemediation: \(.remediation)\n"' 2>/dev/null
    } > cis-remediation-guide.txt
    
    log_info "Remediation guide saved to: cis-remediation-guide.txt"
}

# Main
main() {
    log_info "CIS Kubernetes Benchmark Tool"
    log_info "=============================="
    
    run_benchmark
    display_results
    generate_remediation
    
    log_info ""
    log_info "Benchmark complete!"
}

main "$@"
