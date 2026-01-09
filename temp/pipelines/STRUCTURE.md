# GitLab Pipeline Structure

This document describes the modular pipeline structure for managing image build processes.

## File Tree Structure

```
.
├── .gitlab-ci.yml                          # Main orchestration pipeline (ROOT of repo)
├── pipelines/
│   ├── shared/
│   │   └── variables.yaml                  # Shared variables for all pipelines
│   ├── xelos/
│   │   └── pipeline.yaml                   # Xelos image pipeline
│   └── maptiler/
│       └── pipeline.yaml                   # Maptiler image pipeline
├── ansible/
│   ├── playbook.yml
│   ├── aria-order/
│   │   └── vars/
│   │       └── artifacts.yml
│   ├── aria-scan/
│   │   └── vars/
│   │       └── artifacts.yml
│   └── aria-scanselfbuild/
│       └── vars/
│           └── artifacts.yml
├── docker/
│   ├── xelos/
│   │   └── dockerfile.xelos
│   └── maptiler/
│       └── Dockerfile
└── binaries/
    └── maptiler/
        └── *.deb
```

## Pipeline Architecture

### Main Orchestration Pipeline (.gitlab-ci.yml)
- Located at the **root** of the repository
- Includes shared configuration
- Triggers child pipelines based on rules
- Manages execution order of different image processes

### Child Pipelines

#### 1. Xelos Image Pipeline (pipelines/xelos/pipeline.yaml)
Handles the complete Xelos image lifecycle:
- **Stage: order** - Order Xelos image from registry
- **Stage: wait** - Wait for image to be available in Nexus
- **Stage: build** - Build BWI-specific Xelos image
- **Stage: scan** - Trigger security scan
- **Stage: wait-scan** - Wait for scanned image to be available

**Triggers:**
- Manual: When `XELOS_IMAGE_TAG` is set to a value other than 'Tag value'
- Automatic: When changes are detected in:
  - `ansible/aria-order/vars/artifacts.yml`
  - `pipelines/xelos/**/*`
  - `docker/xelos/**/*`

#### 2. Maptiler Image Pipeline (pipelines/maptiler/pipeline.yaml)
Handles the complete Maptiler image lifecycle:
- **Stage: build** - Build Maptiler image from Ubuntu base
- **Stage: scan** - Trigger security scan

**Triggers:**
- Manual: When `MAPTILER_TRG_IMAGE_TAG` is set to a value other than 'Tag value'
- Automatic: When changes are detected in:
  - `ansible/aria-scan/vars/artifacts.yml`
  - `pipelines/maptiler/**/*`
  - `docker/maptiler/**/*`

### Shared Configuration (pipelines/shared/variables.yaml)
Contains common variables used across all pipelines:
- Vault configuration (VAULT_SERVER_URL, VAULT_AUTH_ROLE, etc.)
- Debug flags
- Other shared settings

## How It Works

1. **Trigger Detection**: GitLab detects changes in the repository or manual pipeline runs
2. **Main Pipeline**: `.gitlab-ci.yml` evaluates rules to determine which child pipelines to trigger
3. **Child Pipelines**: Each triggered child pipeline runs independently with its own stages and jobs
4. **Parallel Execution**: Multiple child pipelines can run in parallel (xelos and maptiler)
5. **Dependencies**: Child pipelines use `strategy: depend` to report status back to main pipeline

## Benefits of This Structure

1. **Modularity**: Each image process is isolated in its own pipeline file
2. **Maintainability**: Easier to understand and modify individual pipelines
3. **Reusability**: Shared variables prevent duplication
4. **Flexibility**: Can run individual pipelines independently
5. **Scalability**: Easy to add new image pipelines by creating new files in `pipelines/`
6. **Selective Execution**: Only affected pipelines run based on file changes
7. **Clear Separation**: Each pipeline has clear responsibilities and boundaries

## Running Pipelines

### Manual Execution
In GitLab UI:
1. Go to CI/CD → Pipelines → Run Pipeline
2. Set variables:
   - `XELOS_IMAGE_TAG`: Tag for Xelos image (triggers Xelos pipeline)
   - `MAPTILER_TRG_IMAGE_TAG`: Tag for Maptiler image (triggers Maptiler pipeline)
3. Click "Run Pipeline"

### Automatic Execution
Pipelines automatically trigger when:
- Changes are pushed to relevant directories
- Artifact configuration files are modified

## Adding New Image Pipelines

To add a new image pipeline:

1. Create a new directory under `pipelines/`:
   ```
   mkdir -p pipelines/my-new-image
   ```

2. Create pipeline file:
   ```
   touch pipelines/my-new-image/pipeline.yaml
   ```

3. Define your stages and jobs in the pipeline file

4. Update `.gitlab-ci.yml` to include the new pipeline:
   ```yaml
   my-new-image-pipeline:
     stage: my-new-image-pipeline
     trigger:
       include:
         - local: 'pipelines/my-new-image/pipeline.yaml'
       strategy: depend
     rules:
       - changes:
           - pipelines/my-new-image/**/*
         when: always
   ```

5. Add a new stage to the main pipeline if needed:
   ```yaml
   stages:
     - xelos-pipeline
     - maptiler-pipeline
     - my-new-image-pipeline  # Add new stage
   ```

## Migration from Monolithic Pipeline

The original monolithic `temp/pipeline.yaml` has been split into:
- `pipelines/xelos/pipeline.yaml` (5 jobs: order, wait, build, scan, wait-scan)
- `pipelines/maptiler/pipeline.yaml` (2 jobs: build, scan)

All shared variables moved to `pipelines/shared/variables.yaml`.

## Notes

- Child pipelines inherit variables from parent but can override them
- Each child pipeline maintains its own artifact and cache management
- Use `strategy: depend` to make parent pipeline wait for child completion
- Child pipelines appear as separate pipeline runs in GitLab UI
