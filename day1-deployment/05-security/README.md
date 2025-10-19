# 🔒 Security Configuration - Day 1 Kubernetes Production

This directory contains comprehensive security configurations for production Kubernetes clusters.

## 📁 Directory Structure

```
05-security/
├── 01-network-policies/          # Network segmentation and policies
├── 02-pod-security/              # Pod Security Standards (PSS) and contexts
├── 03-policy-as-code/            # OPA/Kyverno policy enforcement
├── 04-secrets-management/        # Vault integration and secret encryption
├── 05-runtime-security/          # Falco rules and runtime monitoring
├── 06-rbac/                      # Role-Based Access Control
├── 07-image-security/            # Image scanning and SBOM
├── 08-compliance/                # Audit logging and compliance
├── 09-supply-chain/              # Sigstore and provenance
└── scripts/                      # Security validation scripts
```

## 🎯 Security Layers

### Layer 1: Network Security
- Cilium network policies
- Service mesh mTLS (Istio)
- Ingress/Egress controls
- DNS security

### Layer 2: Pod Security
- Pod Security Standards (restricted profile)
- Security contexts
- Resource constraints
- Admission control

### Layer 3: Policy Enforcement
- OPA Gatekeeper policies
- Kyverno policies
- Automated remediation

### Layer 4: Secrets Management
- HashiCorp Vault integration
- External Secrets Operator
- Encryption at rest (etcd)
- Secret rotation

### Layer 5: Runtime Security
- Falco threat detection
- Tetragon eBPF monitoring
- Anomaly detection

### Layer 6: Access Control
- RBAC configurations
- ServiceAccount management
- OIDC/SAML integration

### Layer 7: Supply Chain
- Cosign image signing
- SBOM generation
- Provenance verification

## 🚀 Quick Start

```bash
# Deploy all security components
./scripts/deploy-security-stack.sh

# Validate security configuration
./scripts/validate-security.sh

# Run CIS Benchmark
./scripts/cis-benchmark.sh
```

## 📚 Related Articles

This code supports **Part 5: Security Configuration** of the Kubernetes Production Journey series.

## ⚠️ Prerequisites

- Kubernetes 1.28+
- kubectl configured
- Helm 3.x
- Access to container registry
- HashiCorp Vault (optional)
