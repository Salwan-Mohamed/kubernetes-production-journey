#!/bin/bash
# Vault Initialization and Configuration Script
# Run this after Vault is deployed to initialize and configure it

set -e

VAULT_ADDR="https://vault.vault.svc.cluster.local:8200"
VAULT_NAMESPACE="production"

echo "================================================"
echo "Vault Initialization Script"
echo "================================================"

# Check if Vault is already initialized
if kubectl exec -n vault vault-0 -- vault status &>/dev/null; then
    echo "âœ" Vault is already initialized"
else
    echo "Initializing Vault..."
    
    # Initialize Vault with 5 key shares and 3 required for unsealing
    INIT_OUTPUT=$(kubectl exec -n vault vault-0 -- vault operator init \
        -key-shares=5 \
        -key-threshold=3 \
        -format=json)
    
    echo "$INIT_OUTPUT" > vault-init-keys.json
    
    echo "âœ" Vault initialized successfully"
    echo "âš  IMPORTANT: Save vault-init-keys.json securely!"
    echo "âš  Store unseal keys and root token in a secure location"
fi

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
kubectl wait --for=condition=Ready pod/vault-0 -n vault --timeout=300s

# Login to Vault (use root token from init output)
echo "Logging in to Vault..."
export VAULT_TOKEN=$(jq -r '.root_token' vault-init-keys.json)

# Enable Kubernetes auth method
echo "Enabling Kubernetes authentication..."
kubectl exec -n vault vault-0 -- vault auth enable kubernetes || true

# Configure Kubernetes auth
echo "Configuring Kubernetes authentication..."
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
    kubernetes_host="https://kubernetes.default.svc:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token

# Enable KV v2 secrets engine
echo "Enabling KV v2 secrets engine..."
kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2 || true

# Create policy for production applications
echo "Creating Vault policies..."
cat <<EOF | kubectl exec -i -n vault vault-0 -- vault policy write production-app -
path "secret/data/production/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/production/*" {
  capabilities = ["read", "list"]
}
EOF

# Create Kubernetes role for production namespace
echo "Creating Kubernetes role..."
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/production-app \
    bound_service_account_names=backend,frontend \
    bound_service_account_namespaces=production \
    policies=production-app \
    ttl=1h

# Store sample secrets
echo "Storing sample secrets..."

# Database credentials
kubectl exec -n vault vault-0 -- vault kv put secret/production/database \
    host="postgres.production.svc.cluster.local" \
    port="5432" \
    database="app_db" \
    username="app_user" \
    password="$(openssl rand -base64 32)"

# API keys
kubectl exec -n vault vault-0 -- vault kv put secret/production/stripe \
    api_key="sk_test_$(openssl rand -hex 24)"

kubectl exec -n vault vault-0 -- vault kv put secret/production/sendgrid \
    api_key="SG.$(openssl rand -base64 32 | tr -d '=+')"

kubectl exec -n vault vault-0 -- vault kv put secret/production/jwt \
    secret="$(openssl rand -base64 64)"

# Enable audit logging
echo "Enabling audit logging..."
kubectl exec -n vault vault-0 -- vault audit enable file \
    file_path=/vault/audit/vault-audit.log || true

# Enable Prometheus metrics
echo "Enabling Prometheus metrics..."
kubectl exec -n vault vault-0 -- vault write sys/metrics/config \
    enabled=true \
    enable_hostname_label=false

echo "================================================"
echo "âœ" Vault initialization complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Securely store vault-init-keys.json"
echo "2. Distribute unseal keys to key holders"
echo "3. Rotate root token: vault token create -policy=root"
echo "4. Deploy External Secrets Operator"
echo "5. Apply ExternalSecret resources"
echo ""
echo "Vault UI: https://vault.example.com"
echo "Root Token: $(jq -r '.root_token' vault-init-keys.json)"
