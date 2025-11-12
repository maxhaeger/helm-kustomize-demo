vault write auth/jwt/role/gitlab-ci-role - <<EOF
{
"role_type": "jwt",
"policies": ["default"],
"token_explicit_max_ttl": 3600,
"user_claim": "user_email",
"bound_audiences": "https://vault.konvoi.svc.intdev.cloud.bwi.intranet-bw.de",
"bound_claims": {
"project_id": "\*"
}
}
EOF

---


vault policy write gitlab-ci-deployment - <<EOF
# Read-only access für GitLab Deployment Secrets
path "i0000041vpc0000001-secrets/data/gitlab/deployment_*" {
  capabilities = ["read"]
}

path "i0000041vpc0000001-secrets/data/gitlab/*" {
  capabilities = ["read"]
}

# Falls du auch metadata brauchst
path "i0000041vpc0000001-secrets/metadata/gitlab/*" {
  capabilities = ["read", "list"]
}
EOF
