# Security Configuration

This directory contains comprehensive security configurations for Kubernetes Day 1 deployment.

## Directory Structure

```
05-security-configuration/
├── network-policies/          # Network segmentation and policies
├── pod-security/             # Pod Security Standards and policies
├── rbac/                     # Role-Based Access Control
├── secrets-management/       # Secrets encryption and Vault integration
├── image-security/           # Image scanning and SBOM
├── runtime-security/         # Falco and runtime protection
├── compliance/               # Audit logging and compliance
├── supply-chain/             # Sigstore and provenance
└── security-validation/      # Security testing and validation
```

## Components

### 1. Network Security
- Default deny policies
- Namespace isolation
- Istio mTLS configuration
- Cilium eBPF policies

### 2. Pod Security
- Pod Security Standards (PSS)
- OPA/Kyverno policies
- Security contexts
- Service account configuration

### 3. RBAC Configuration
- Least privilege roles
- Service account bindings
- User and group management

### 4. Secrets Management
- HashiCorp Vault integration
- External Secrets Operator
- Encryption at rest (etcd)
- Secret rotation policies

### 5. Image Security
- Trivy scanning
- SBOM generation
- Image signing with Cosign
- Admission controller integration

### 6. Runtime Security
- Falco rule deployment
- Alert configuration
- Threat detection

### 7. Compliance & Audit
- Audit logging configuration
- CIS Kubernetes Benchmark
- Compliance reporting

### 8. Supply Chain Security
- Sigstore integration
- SLSA attestations
- Policy enforcement

## Quick Start

1. Apply network policies:
```bash
kubectl apply -f network-policies/
```

2. Configure Pod Security:
```bash
kubectl apply -f pod-security/
```

3. Setup RBAC:
```bash
kubectl apply -f rbac/
```

4. Deploy Vault:
```bash
helm install vault -f secrets-management/vault-values.yaml hashicorp/vault
```

5. Install Falco:
```bash
helm install falco -f runtime-security/falco-values.yaml falcosecurity/falco
```

## Security Validation

Run the validation script:
```bash
./security-validation/validate-security.sh
```

## Related Documentation

- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [NIST SP 800-190](https://csrc.nist.gov/publications/detail/sp/800-190/final)
