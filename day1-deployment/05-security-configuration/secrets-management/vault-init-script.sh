#!/bin/bash
# Vault Initialization and Configuration Script
# Run this after Vault installation to set up authentication and policies

set -e

VAULT_ADDR="https://vault.vault.svc.cluster.local:8200"
VAULT_NAMESPACE="production"

echo "==> Initializing Vault (if not already initialized)"
if ! kubectl exec -n vault vault-0 -- vault status > /dev/null 2>&1; then
  kubectl exec -n vault vault-0 -- vault operator init \
    -key-shares=5 \
    -key-threshold=3 \
    -format=json > vault-keys.json
  
  echo "⚠️  CRITICAL: Save vault-keys.json securely! This contains unseal keys and root token."
  echo "⚠️  Store in a secure location (password manager, secrets management system)"
fi

echo "==> Unsealing Vault (if using manual unseal)"
# If using AWS KMS auto-unseal, skip this step
# UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' vault-keys.json)
# UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' vault-keys.json)
# UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' vault-keys.json)
# kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_1
# kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_2
# kubectl exec -n vault vault-0 -- vault operator unseal $UNSEAL_KEY_3

echo "==> Logging in to Vault"
ROOT_TOKEN=$(jq -r '.root_token' vault-keys.json)
kubectl exec -n vault vault-0 -- vault login $ROOT_TOKEN

echo "==> Enabling Kubernetes authentication"
kubectl exec -n vault vault-0 -- vault auth enable kubernetes || true

echo "==> Configuring Kubernetes auth"
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token

echo "==> Creating policies"
kubectl exec -n vault vault-0 -- vault policy write production-app - <<EOF
path "secret/data/database/production/*" {
  capabilities = ["read", "list"]
}

path "secret/data/api-keys/production/*" {
  capabilities = ["read", "list"]
}

path "secret/data/certificates/production/*" {
  capabilities = ["read", "list"]
}
EOF

echo "==> Creating Kubernetes role"
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/production-app \
  bound_service_account_names=external-secrets,backend,frontend \
  bound_service_account_namespaces=$VAULT_NAMESPACE \
  policies=production-app \
  ttl=24h

echo "==> Enabling KV v2 secrets engine"
kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2 || true

echo "==> Creating sample secrets"
kubectl exec -n vault vault-0 -- vault kv put secret/database/production/postgres \
  username="app_user" \
  password="changeme_$(openssl rand -base64 32)" \
  host="postgres.production.svc.cluster.local" \
  port="5432" \
  database="production_db"

echo "==> Vault configuration complete!"
echo ""
echo "Next steps:"
echo "1. Install External Secrets Operator"
echo "2. Create SecretStore resources"
echo "3. Create ExternalSecret resources"
echo "4. Verify secrets are synchronized"
