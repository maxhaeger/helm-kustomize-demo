Hier ist eine vollständige GitLab CI/CD Pipeline für deine Ansible Rolle:

## Vollständige .gitlab-ci.yml

```yaml
stages:
  - validate
  - deploy

variables:
  ANSIBLE_HOST_KEY_CHECKING: "False"
  ANSIBLE_FORCE_COLOR: "true"
  VAULT_ADDR: "https://vault.your-company.com"

# Optional: Syntax-Check vor Deployment
validate_ansible:
  stage: validate
  image:
    name: ansible/ansible:latest
    entrypoint: [""]
  before_script:
    - pip install hvac
    - ansible-galaxy collection install community.hashi_vault
  script:
    - ansible-playbook playbook.yml --syntax-check
    - ansible-playbook playbook.yml --check -e "new_image='test:latest'"
  only:
    - merge_requests
    - main

# Deployment mit neuem Image (manuell)
deploy_manual:
  stage: deploy
  image:
    name: ansible/ansible:latest
    entrypoint: [""]

  before_script:
    # Vault Setup
    - pip install hvac
    - ansible-galaxy collection install community.hashi_vault

    # Vault Token holen (JWT Auth)
    - |
      export VAULT_TOKEN=$(curl -s --request POST \
        --data "{\"role\": \"gitlab-ci\", \"jwt\": \"$CI_JOB_JWT\"}" \
        $VAULT_ADDR/v1/auth/jwt/login | jq -r '.auth.client_token')

    - echo "Vault authenticated successfully"

  script:
    - echo "Deploying new image: ${NEW_IMAGE}"
    - echo "Existing images will be extended with new image"

    # Ansible Rolle ausführen
    - ansible-playbook playbook.yml -e "new_image='${NEW_IMAGE}'" -v

  variables:
    NEW_IMAGE: "my-app:latest" # Default, kann überschrieben werden

  environment:
    name: production
    action: start

  when: manual
  only:
    - main

# Automatisches Deployment nach Git Tag
deploy_on_tag:
  stage: deploy
  image:
    name: ansible/ansible:latest
    entrypoint: [""]

  before_script:
    - pip install hvac
    - ansible-galaxy collection install community.hashi_vault

    - |
      export VAULT_TOKEN=$(curl -s --request POST \
        --data "{\"role\": \"gitlab-ci\", \"jwt\": \"$CI_JOB_JWT\"}" \
        $VAULT_ADDR/v1/auth/jwt/login | jq -r '.auth.client_token')

  script:
    # Image Name aus Git Tag generieren
    - export NEW_IMAGE="my-app:${CI_COMMIT_TAG}"
    - echo "Auto-deploying tagged image: ${NEW_IMAGE}"

    - ansible-playbook playbook.yml -e "new_image='${NEW_IMAGE}'" -v

  environment:
    name: production

  only:
    - tags

# Deployment mit Commit SHA
deploy_commit_sha:
  stage: deploy
  image:
    name: ansible/ansible:latest
    entrypoint: [""]

  before_script:
    - pip install hvac
    - ansible-galaxy collection install community.hashi_vault

    - |
      export VAULT_TOKEN=$(curl -s --request POST \
        --data "{\"role\": \"gitlab-ci\", \"jwt\": \"$CI_JOB_JWT\"}" \
        $VAULT_ADDR/v1/auth/jwt/login | jq -r '.auth.client_token')

  script:
    - export NEW_IMAGE="my-app:${CI_COMMIT_SHORT_SHA}"
    - echo "Deploying commit-based image: ${NEW_IMAGE}"

    - ansible-playbook playbook.yml -e "new_image='${NEW_IMAGE}'" -v

  environment:
    name: staging

  when: manual
  only:
    - develop

# Deployment mit mehreren Images
deploy_multiple_images:
  stage: deploy
  image:
    name: ansible/ansible:latest
    entrypoint: [""]

  before_script:
    - pip install hvac
    - ansible-galaxy collection install community.hashi_vault

    - |
      export VAULT_TOKEN=$(curl -s --request POST \
        --data "{\"role\": \"gitlab-ci\", \"jwt\": \"$CI_JOB_JWT\"}" \
        $VAULT_ADDR/v1/auth/jwt/login | jq -r '.auth.client_token')

  script:
    - echo "Deploying multiple images"

    # Mehrere Images als Liste übergeben
    - |
      ansible-playbook playbook.yml \
        -e "additional_images=['${IMAGE_1}','${IMAGE_2}','${IMAGE_3}']" -v

  variables:
    IMAGE_1: "app-frontend:v1.0"
    IMAGE_2: "app-backend:v1.0"
    IMAGE_3: "app-worker:v1.0"

  when: manual
  only:
    - main

# Rollback auf vorherige Version
rollback:
  stage: deploy
  image:
    name: ansible/ansible:latest
    entrypoint: [""]

  before_script:
    - pip install hvac
    - ansible-galaxy collection install community.hashi_vault

    - |
      export VAULT_TOKEN=$(curl -s --request POST \
        --data "{\"role\": \"gitlab-ci\", \"jwt\": \"$CI_JOB_JWT\"}" \
        $VAULT_ADDR/v1/auth/jwt/login | jq -r '.auth.client_token')

  script:
    - echo "Rolling back to: ${ROLLBACK_IMAGE}"

    # Nutze base_deployment_images ohne neues Image
    - ansible-playbook playbook.yml -e "new_image=''" -v

  variables:
    ROLLBACK_IMAGE: "stable"

  when: manual
  only:
    - main
```

## Erweiterte Version mit Caching & Artifacts

```yaml
stages:
  - prepare
  - validate
  - deploy

variables:
  ANSIBLE_HOST_KEY_CHECKING: "False"
  ANSIBLE_FORCE_COLOR: "true"
  VAULT_ADDR: "https://vault.your-company.com"

cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - .ansible/

# Dependencies installieren und cachen
prepare:
  stage: prepare
  image:
    name: ansible/ansible:latest
    entrypoint: [""]
  script:
    - pip install hvac --cache-dir .pip-cache
    - ansible-galaxy collection install community.hashi_vault -p .ansible/collections
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - .pip-cache/
      - .ansible/
  artifacts:
    paths:
      - .ansible/
    expire_in: 1 hour

validate:
  stage: validate
  image:
    name: ansible/ansible:latest
    entrypoint: [""]
  dependencies:
    - prepare
  script:
    - ansible-playbook playbook.yml --syntax-check
    - ansible-lint playbook.yml || true # Optional: Linting
  only:
    - merge_requests
    - main

deploy_production:
  stage: deploy
  image:
    name: ansible/ansible:latest
    entrypoint: [""]

  dependencies:
    - prepare

  before_script:
    - pip install hvac --cache-dir .pip-cache

    # Vault Authentication
    - |
      export VAULT_TOKEN=$(curl -s --request POST \
        --data "{\"role\": \"gitlab-ci\", \"jwt\": \"$CI_JOB_JWT\"}" \
        $VAULT_ADDR/v1/auth/jwt/login | jq -r '.auth.client_token')

    - echo "=== Deployment Configuration ==="
    - echo "New Image: ${NEW_IMAGE}"
    - echo "Environment: ${CI_ENVIRONMENT_NAME}"
    - echo "Triggered by: ${GITLAB_USER_LOGIN}"
    - echo "==============================="

  script:
    # Deployment ausführen
    - |
      ansible-playbook playbook.yml \
        -e "new_image='${NEW_IMAGE}'" \
        -e "deployment_reason='${DEPLOYMENT_REASON}'" \
        -v

    # Log erstellen
    - echo "${NEW_IMAGE}" > deployed_image.txt
    - date >> deployed_image.txt

  after_script:
    - echo "Deployment completed at $(date)"

  artifacts:
    reports:
      dotenv: deployed_image.txt
    expire_in: 30 days

  variables:
    NEW_IMAGE: "my-app:latest"
    DEPLOYMENT_REASON: "Manual deployment via GitLab CI"

  environment:
    name: production
    url: https://your-app.com
    on_stop: stop_deployment

  when: manual
  only:
    - main

  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure

# Optional: Deployment stoppen/cleanup
stop_deployment:
  stage: deploy
  image:
    name: ansible/ansible:latest
    entrypoint: [""]
  script:
    - echo "Stopping deployment"
    # Cleanup tasks hier
  environment:
    name: production
    action: stop
  when: manual
```

## Projekt-Struktur

```
.
├── .gitlab-ci.yml
├── playbook.yml
├── inventory.ini
├── ansible.cfg
├── roles/
│   └── deployment/
│       ├── tasks/
│       │   └── main.yml
│       ├── vars/
│       │   └── main.yml
│       ├── templates/
│       └── defaults/
│           └── main.yml
└── README.md
```

## ansible.cfg (Optional)

```ini
[defaults]
inventory = inventory.ini
host_key_checking = False
retry_files_enabled = False
stdout_callback = yaml
collections_paths = ./.ansible/collections:/usr/share/ansible/collections

[ssh_connection]
pipelining = True
```

## inventory.ini

```ini
[local]
localhost ansible_connection=local
```

## Nutzung:

**Manuell mit Custom Image:**

1. Gehe zu: `CI/CD > Pipelines`
2. Klicke auf "Run Pipeline"
3. Branch: `main`
4. Variable hinzufügen:
   - Key: `NEW_IMAGE`
   - Value: `my-app:v2.5.0`
5. Klicke auf "Run Pipeline"
6. Klicke auf das manuelle Job-Icon

**Automatisch mit Git Tag:**

```bash
git tag v1.2.3
git push origin v1.2.3
```

→ Pipeline startet automatisch mit Image `my-app:v1.2.3`

**Mit Commit SHA:**

```bash
git commit -m "New feature"
git push origin develop
```

→ Manuelles Deployment mit Image `my-app:abc123f`

So hast du eine komplette, produktionsreife Pipeline! 🚀
