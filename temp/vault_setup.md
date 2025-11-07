Perfekt! Hier ist die Schritt-für-Schritt-Anleitung für die Vault GUI:

## 1. Secrets Engine einrichten (falls noch nicht vorhanden)

**Wenn KV Secrets Engine bereits existiert:**

- Navigiere zu: **Secrets** (linkes Menü)
- Du solltest bereits einen Mount Point sehen (z.B. `secret/`)

**Falls neu erstellen:**

- Klicke auf **Enable new engine**
- Wähle **KV** (Key-Value)
- Wähle **Version 2**
- Path: `secret` (oder dein gewünschter Name)
- Klicke **Enable Engine**

## 2. GitLab Ordner und Secrets erstellen

### Schritt 1: Navigiere zu deinem Secrets Path

```
Secrets → secret/ → Create secret
```

### Schritt 2: Erstelle den gitlab/ Pfad mit API Token

```
Path: gitlab/deployment/api_token

Secret data:
┌─────────────┬──────────────────────────────────────┐
│ Key         │ Value                                │
├─────────────┼──────────────────────────────────────┤
│ token       │ dein-bearer-token-hier               │
└─────────────┴──────────────────────────────────────┘

[Save]
```

### Schritt 3: Weitere Secrets hinzufügen (optional)

```
Path: gitlab/deployment/config

Secret data:
┌─────────────────┬──────────────────────────────────────┐
│ Key             │ Value                                │
├─────────────────┼──────────────────────────────────────┤
│ deployment_url  │ https://boe-ind-vna-00.mgmt...       │
│ deployment_id   │ 65702a43-2b8a-4252-9301-c13c8286fd67 │
└─────────────────┴──────────────────────────────────────┘

[Save]
```

## 3. JWT Auth Method für GitLab einrichten

### Via GUI (wenn möglich):

**Access → Auth Methods → Enable new method**

```
Type: JWT
Path: jwt
Description: GitLab CI/CD Authentication
```

**Nach dem Enablen, konfiguriere:**

```
JWKS URL: https://gitlab.com/-/jwks
(oder für Self-Hosted: https://your-gitlab.com/-/jwks)

Bound Issuer: gitlab.com
(oder für Self-Hosted: your-gitlab.com)
```

### Via Vault CLI (falls GUI nicht ausreicht):

```bash
vault auth enable jwt

vault write auth/jwt/config \
    jwks_url="https://gitlab.com/-/jwks" \
    bound_issuer="gitlab.com"
```

## 4. Policy für GitLab CI erstellen

**Policies → Create ACL Policy**

```
Name: gitlab-ci-policy

Policy:
# Lesen von Secrets im gitlab/ Pfad
path "secret/data/gitlab/*" {
  capabilities = ["read", "list"]
}

# Optional: Auch k8s/ Secrets lesen
path "secret/data/k8s/*" {
  capabilities = ["read"]
}

# Metadata lesen
path "secret/metadata/gitlab/*" {
  capabilities = ["read", "list"]
}
```

Klicke **Create policy**

## 5. JWT Role für GitLab erstellen

**Access → Auth Methods → jwt/ → Create role**

```
Role name: gitlab-ci

Role Type: jwt

Bound Claims (JSON):
{
  "project_id": "DEINE_GITLAB_PROJECT_ID",
  "ref_protected": "true"
}

User Claim: user_email

Policies: gitlab-ci-policy

TTL: 3600 (1 Stunde)

Max TTL: 7200 (2 Stunden)
```

### GitLab Project ID finden:

1. Gehe zu deinem GitLab Projekt
2. **Settings → General**
3. Ganz oben siehst du: **Project ID: 12345**

## 6. Secrets-Struktur im Vault

Nach der Einrichtung sollte deine Struktur so aussehen:

```
secret/
├── k8s/
│   ├── credentials
│   └── config
│
└── gitlab/
    └── deployment/
        ├── api_token
        │   └── token: "Bearer eyJ..."
        └── config
            ├── deployment_url: "https://..."
            └── deployment_id: "65702a43..."
```

## 7. Ansible Konfiguration

**vars/main.yml:**

```yaml
# Vault Configuration
vault_addr: "{{ lookup('env', 'VAULT_ADDR') }}"
vault_token: "{{ lookup('env', 'VAULT_TOKEN') }}"

# Secrets aus gitlab/ Pfad holen
api_token: "{{ lookup('community.hashi_vault.hashi_vault',
  'secret=secret/data/gitlab/deployment/api_token:token
  token=' + vault_token + '
  url=' + vault_addr) }}"

deployment_url: "{{ lookup('community.hashi_vault.hashi_vault',
  'secret=secret/data/gitlab/deployment/config:deployment_url
  token=' + vault_token + '
  url=' + vault_addr) }}"

# Oder alle Secrets auf einmal holen
deployment_secrets: "{{ lookup('community.hashi_vault.hashi_vault',
  'secret=secret/data/gitlab/deployment/api_token
  token=' + vault_token + '
  url=' + vault_addr) }}"
```

**Oder einfacher mit separater Task:**

**tasks/vault.yml:**

```yaml
---
- name: Get API Token from Vault
  set_fact:
    api_token: "{{ lookup('community.hashi_vault.hashi_vault',
      'secret=secret/data/gitlab/deployment/api_token:token') }}"

- name: Get Deployment Config from Vault
  set_fact:
    deployment_config: "{{ lookup('community.hashi_vault.hashi_vault',
      'secret=secret/data/gitlab/deployment/config') }}"

- name: Set deployment URL
  set_fact:
    deployment_url: "{{ deployment_config.deployment_url }}"
```

## 8. GitLab CI anpassen

**.gitlab-ci.yml:**

```yaml
deploy:
  stage: deploy
  image:
    name: ansible/ansible:latest
    entrypoint: [""]

  before_script:
    - pip install hvac
    - ansible-galaxy collection install community.hashi_vault

    # Vault Login mit GitLab JWT
    - export VAULT_ADDR="https://vault.your-company.com"
    - |
      export VAULT_TOKEN=$(curl -s --request POST \
        --data "{\"role\": \"gitlab-ci\", \"jwt\": \"${CI_JOB_JWT}\"}" \
        ${VAULT_ADDR}/v1/auth/jwt/login | jq -r '.auth.client_token')

    - echo "Vault token acquired"

    # Verify Vault access
    - |
      curl -s --header "X-Vault-Token: ${VAULT_TOKEN}" \
        ${VAULT_ADDR}/v1/secret/data/gitlab/deployment/api_token | jq

  script:
    - ansible-playbook playbook.yml -e "new_image='${NEW_IMAGE}'" -v

  id_tokens:
    VAULT_ID_TOKEN:
      aud: https://vault.your-company.com
```

## 9. Test in Vault GUI

**Secrets testen:**

1. Navigiere zu: **Secrets → secret → gitlab → deployment → api_token**
2. Klicke auf das Secret
3. Du solltest sehen:

   ```
   Version: 1
   Created: ...

   Data:
   token: ey... (klicke auf 👁️ um zu sehen)
   ```

**Policy testen:**

1. **Access → Auth Methods → jwt → gitlab-ci**
2. Klicke **Generate Token** (zum Testen)
3. Kopiere Token
4. Teste API Zugriff:

```bash
curl -H "X-Vault-Token: YOUR_TEST_TOKEN" \
  https://vault.your-company.com/v1/secret/data/gitlab/deployment/api_token
```

## 10. Troubleshooting Checklist

**Falls Ansible keine Secrets lesen kann:**

✅ **Prüfe Vault Token:**

```yaml
- name: Debug Vault Token
  debug:
    msg: "Vault Token: {{ vault_token[:10] }}..." # Nur erste 10 Zeichen
```

✅ **Prüfe Secret Path:**

```yaml
- name: Test Vault Connection
  uri:
    url: "{{ vault_addr }}/v1/secret/data/gitlab/deployment/api_token"
    headers:
      X-Vault-Token: "{{ vault_token }}"
    method: GET
  register: vault_test

- name: Show result
  debug:
    var: vault_test
```

✅ **Permission denied?**

- Prüfe Policy: Ist `secret/data/gitlab/*` erlaubt?
- Prüfe Role Binding: Stimmt die Project ID?

✅ **JWT Auth failed?**

- Prüfe JWKS URL in Vault
- Prüfe `bound_issuer` (gitlab.com vs your-gitlab.com)
- Prüfe ob `id_tokens` in .gitlab-ci.yml definiert ist

## Quick Reference - Vault Paths

```
Vault GUI Navigation:
├── Secrets (Tab)
│   └── secret/
│       ├── k8s/          ← Bereits vorhanden
│       └── gitlab/       ← Neu erstellen
│           └── deployment/
│               ├── api_token
│               └── config
│
└── Access (Tab)
    ├── Auth Methods
    │   └── jwt/
    │       └── gitlab-ci (Role)
    └── Policies
        └── gitlab-ci-policy
```

Brauchst du Hilfe bei einem spezifischen Schritt? 🔐
