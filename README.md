# Flux CD with Terraform

Template for creating a GitOps repository with Flux CD and Terraform.

## Requirements

For bootstraping, encrypting/derypting secret:

- [SOPS](https://github.com/mozilla/sops)
- [yq](https://github.com/mikefarah/yq)
- [terraform](https://developer.hashicorp.com/terraform/install)
- [terragrunt](https://github.com/gruntwork-io/terragrunt)

If you don't have the required tools, run this command to install them locally for this project.

```sh
make install-tools
```

Additionally, you need the following tools to work with the clusters:

- [Kubernetes CLI](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [Flux CLI](https://fluxcd.io/docs/installation/)

## Getting started

### Cluster init

To generate intial files & directories for a new cluster, use the make target `cluster-init` e.g.

```sh
make cluster-init CLUSTER=production
```

The cluster directory `tg/clusters/production` will be generated with some initial variables in `terraform.tfvars` file.
The file contains minimal variables needed to bootstrap a new cluster. Modify them with your variables.
Additionally, a `backend.tfvars` file will also be created in `tg/clusters` if it doesn't exist, containing default
values for backend configuration. You should modify them as needed.

### Bootstrap cluster

After filling variables for your cluster, prepare your SOPS keys if you haven't. Add your SOPS recipient using command.

```sh
make sops-add
```

Next, encrypt your secret files.

```sh
make encrypt
```

Commit and push your secrets. Then run the following command to bootstrap the cluster.

```sh
make bootstrap CLUSTER='<your_cluster>'
```

The first time you run, `.terraform.lock.hcl` will also be created. Commit and push it.
If you use local state backend (default), also run `make encrypt` to encrypt the newly created `terraform.tfstate` file
and commit it. You can start writing Flux Kustomizations and manifests now.
Add the relevant paths to `sops.yaml`so they can be encrypted.

## Secrets

Secret files are encrypted using SOPS and have the `.enc` suffix appended to the original
unencrypted file's basename. e.g. `values.yaml` -> `values.enc.yaml`.
Only their encrypted counterparts in the same directory should be committed to version control.

Secret encryption rules are defined in [sops.yaml](./sops.yaml).

Generally, the following files need to be encrypted:

- Helm values files
- Secret files (files matching pattern secret.*)
- Terraform variables (*.tfvars)

### `sops.yaml` file

This file is similar to SOPS's `.sops.yaml` configuration file but is slightly different in how recipientes are defined.
It should have the following keys.

- `recipients`: SOPS recipients, keyed by name. Each recipient is an object with the following possible keys
  - `age`: age public key
  - `...`: TODO more to add
- `paths`: Encryption rules. Each encryption rule should have the following keys
  - `path_regex`: Terraform [fileset](https://developer.hashicorp.com/terraform/language/functions/fileset) pattern to search for secret files
  - `recipients`: List of recipients by their names, as defined above. This list can be nested so YAML anchors can be used.

Example:

```yaml
recipients:
  fluxcd: agepublickey
paths:
  path_regex: "{apps,infrastructure}/staging/**/{secret,values}*.{*}"
    recipients:
    - fluxcd
```

### Adding recipients

To add or update SOPS recipient, use the `sops-add` target, then enter recipient name and key.

```sh
make sops-add
```

The following variables are available:

- `NAME`: recipient name. Will be asked to enter if not specified.
- `GROUPS`: groups to add the recipient to. Specify empty string (`""`) for no group. Default is `human`.
- `TYPE`: recipient type. Default is `age`.

For example, to add a flux recipient:

```sh
make sops-add NAME=flux-production GROUPS=''
```

### Encrypting secrets

Run the following command to encrypt secret files matching patterns defined in `sops.yaml`.

```sh
make encrypt
```

**NOTE**:

- Only changed files are re-encrypted.
- Be careful with dangling unencrypted files after their encrypted counterparts are deleted upstream.
  You may accidentally commit them again.

**WARNING**:
Everytime you pull changes from remote repository, make sure you run the descrypt script first to ensure you have
the latest version of the encrypted files before editing and encrypting.
Otherwise you may unintentionally override the latest changes and commit an outdated version.

### Decrypting secrets

Run the following command to encrypt secret files matching patterns defined in `sops.yaml`.

```sh
make decrypt
```

**WARNING**: This will override your current file so be careful not to lost your current work.

## Troubleshooting

### Build Flux kustomization

During development, you can use make target `build` to build Flux kustomizations. You can view Flux custom resources
(HelmRelease, OCIRepo, ImagePolicy, ImageUpdatAutomation...) and any other resources included in the kustomization.
Specifying `KS` and `CLUSTER` is required. There're also targets `apps` and `infrastructure` to build the corresponding
kustomization. For example, this command will build Flux kustomization in `clusters/production/apps.yaml`.

```sh
make build KS=apps CLUSTER=production

# or
make apps CLUSTER=production
```

`NS` can also be specified to only show resources in specific namespace. For example, this command will show manifests
for resources in namespace `ingress-nginx` in `clusters/production/infrastructure.yaml`.

```sh
make infrastructure CLUSTER=production NS=ingress-nginx
```

Make sure to test Kustomization with this command before committing to avoid error during application on live cluster.

### Terragrunt log

By default, only Terraform output is shown.
Terragrunt logs are suppressed so errors in `terragrunt.hcl` files are not visible.
If you encounter an error without any explanation, try running make targets with `DEBUG=true` for more verbose logging.
