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
