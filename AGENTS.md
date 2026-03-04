# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is  a GitOps infrastructure repository using **Flux CD v2** and **Terraform/Terragrunt** to manage Kubernetes clusters. It deploys applications and infrastructure across production, staging, and POC environments on Linode LKE.

## Common Commands

### Validate manifests (always do this before committing)

```sh
make build KS=apps CLUSTER=production
make apps CLUSTER=production            # shorthand
make infrastructure CLUSTER=production
make rbac CLUSTER=production
```

Filter by namespace with `NS=<namespace>`:

```sh
make infrastructure CLUSTER=production NS=ingress-nginx
```

### Secret management

```sh
make decrypt          # decrypt all secrets (run after git pull)
make encrypt          # encrypt changed secret files
make sops-add         # add a new SOPS recipient
```

### Cluster operations

```sh
make cluster-init CLUSTER=<name>    # scaffold a new cluster
make bootstrap CLUSTER=<name>      # bootstrap Flux on a cluster
make install-tools                  # install SOPS, yq, terraform, terragrunt locally
```

Set `DEBUG=true` on any make target for verbose Terragrunt logging.

## Architecture

### Directory Layout

- `apps/{base,production,staging,poc}/` - Application HelmReleases per environment
- `infrastructure/{base,production}/` - Cluster infrastructure (ingress-nginx, cert-manager, monitoring, etc.)
- `components/` - Reusable Kustomize components (databases, patches, flux-common)
- `clusters/production/` - Flux Kustomization entry points that tie everything together
- `rbac/` - Capsule multi-tenancy and RBAC definitions
- `tg/` - Terraform/Terragrunt configs for cluster bootstrap and SOPS operations
- `scripts/` - Shell scripts for bootstrap, encryption, tooling

### Kustomize Layering Pattern

Configuration flows through layers:
```
apps/base/{app}/         → base HelmRelease + OCIRepository
apps/{environment}/{app}/ → environment-specific overrides + encrypted values
components/patches/       → cross-cutting patches (registry auth, image automation)
clusters/{env}/*.yaml     → Flux Kustomization combining layers + components
```

### Per-Application Structure

Each application directory typically contains:
- `release.yaml` - HelmRelease defining chart version, values
- `values.enc.yaml` - SOPS-encrypted Helm values (secrets)
- `kustomization.yaml` - Kustomize config, often with `secretGenerator` for encrypted files
- Optional: `image-policy.yaml`, `image-repository.yaml` for Flux image automation

### Secret Encryption

- Uses **SOPS with Age keys**. Rules defined in `sops.yaml`.
- Unencrypted files: `values.yaml`, `secret.yaml` (gitignored)
- Encrypted files: `values.enc.yaml`, `secret.enc.yaml` (committed)
- Always run `make decrypt` after pulling to get latest secrets before editing.
- Always run `make encrypt` after editing secrets, before committing.
- Different recipient groups exist for production vs staging paths.

### Flux Image Automation

Image tags are automatically updated via Flux ImagePolicy/ImageRepository resources. Automated commits follow the pattern:
```
chore(env, app): automated image updates (Flux)
```

#### Required Files

To add image automation to an application, create these files in the app's environment directory:

1. **imagerepository.yaml** - Defines which container registry to watch:
   ```yaml
   apiVersion: image.toolkit.fluxcd.io/v1
   kind: ImageRepository
   metadata:
     name: <app-name>
     annotations:
       kustomize-patch/pull-secret: global
   spec:
     image: <registry_url>/<repo>
     interval: 5m
   ```

2. **imagepolicy.yaml** - Defines which tags to select:
   ```yaml
   apiVersion: image.toolkit.fluxcd.io/v1
   kind: ImagePolicy
   metadata:
     name: <app-name>
   spec:
     imageRepositoryRef:
       name: <app-name>
     filterTags:
       pattern: '^main-(?P<major>\d{4})\.(?P<minor>\d{1,2})\.(?P<patch>\d{1,2})-gha\.r(?P<run>\d+)$'
       extract: '0.$major$minor$patch.$run'
     policy:
       semver:
         range: ">=0"
   ```

3. **imageupdateautomation.yaml** - Enables automatic commits:
   ```yaml
   apiVersion: image.toolkit.fluxcd.io/v1
   kind: ImageUpdateAutomation
   metadata:
     name: <app-name>
   spec:
     update:
       path: ./apps/<environment>/<app-name>
   ```

#### Tag Patterns

- **Staging/POC**: `main-YYYY.MM.DD-gha.rN` (e.g., `main-2026.02.07-gha.r123`)
- **Production**: May use `stable-*` pattern or specific release tags

#### Marker Comments

Add marker comments in `release.yaml` to tell Flux where to update tags:
```yaml
spec:
  values:
    image:
      tag: main-2026.02.07-gha.r123 # {"$imagepolicy": "<namespace>:<policy-name>:tag"}
```

The marker format is `# {"$imagepolicy": "<namespace>:<imagepolicy-name>:tag"}` where:
- `<namespace>` is the Kubernetes namespace (e.g., `clio-staging`, `avatar-gen-poc`)
- `<imagepolicy-name>` is the ImagePolicy resource name

#### Kustomization Integration

Add the new resources to `kustomization.yaml`:
```yaml
resources:
  - imagerepository.yaml
  - imagepolicy.yaml
  - imageupdateautomation.yaml
```

The `kustomize-patch/pull-secret: global` annotation enables registry authentication via the `global-pull-secret` component.

## Conventions

- **Commit messages**: `feat|fix|chore(environment, app): description`
- **Indentation**: 2 spaces for YAML, shell, Terraform, JSON. Tabs for Makefile.
- **Line endings**: LF only.
- **File naming**: Encrypted files use `.enc.` suffix (e.g., `values.enc.yaml`).
- `clusters/*/flux-system/` is auto-generated by Flux and should not be manually edited.
- Encrypted `*.enc.*` files should not be searched or read directly; decrypt first.
