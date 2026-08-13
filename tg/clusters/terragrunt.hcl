locals {
  tg_root_dir = "${get_repo_root()}/tg"

  terragrunt_tfvars_files = [for file in [
    "${get_parent_terragrunt_dir()}/terragrunt.default.tfvars",
    "${get_parent_terragrunt_dir()}/terragrunt.tfvars",
    "${get_parent_terragrunt_dir()}/terragrunt.tfvars.json"
  ] : file if fileexists(file)]

  config_vars = merge({
    backend = {
      type = "local"

      local = {
        path_prefix = ""
      }

      s3 = {}
    }
  }, [
    for file in local.terragrunt_tfvars_files : jsondecode(read_tfvars_file(file))
  ]...)

  backend_config = local.config_vars.backend
  kubernetes_config = local.config_vars.kubernetes

  # Only render the connection attributes that are actually set, so partial
  # configs (e.g. host + insecure only) don't break on null interpolation.
  kubernetes_provider_attrs = join("\n", compact([
    "host                   = \"${local.kubernetes_config.host}\"",
    lookup(local.kubernetes_config, "cluster_ca_certificate", null) != null ? "cluster_ca_certificate = base64decode(\"${local.kubernetes_config.cluster_ca_certificate}\")" : "",
    lookup(local.kubernetes_config, "token", null) != null ? "token                  = \"${local.kubernetes_config.token}\"" : "",
    lookup(local.kubernetes_config, "client_certificate", null) != null ? "client_certificate     = base64decode(\"${local.kubernetes_config.client_certificate}\")" : "",
    lookup(local.kubernetes_config, "client_key", null) != null ? "client_key             = base64decode(\"${local.kubernetes_config.client_key}\")" : "",
    lookup(local.kubernetes_config, "insecure", null) != null ? "insecure               = ${local.kubernetes_config.insecure}" : "",
  ]))

  backend_local_enabled = local.backend_config.type == "local"
  backend_s3_enabled = local.backend_config.type == "s3" && lookup(local.backend_config.s3, "endpoint", "") == null
  backend_s3_compatible_enabled = local.backend_config.type == "s3" && lookup(local.backend_config.s3, "endpoint", "") != null
}

terraform {
  source = "git::git@github.com:sun-asterisk-research/flux-tf.git//modules/bootstrap?depth=1"

  extra_arguments "common_tfvars" {
    commands = [
      "apply",
      "plan",
    ]

    optional_var_files = [
      "${get_parent_terragrunt_dir()}/terraform.tfvars",
      "${get_parent_terragrunt_dir()}/terraform.tfvars.json"
    ]
  }
}

download_dir = "${local.tg_root_dir}/.terragrunt-cache"

inputs = {
  # Add or modify your input variables here

  # Secret name for SOPS age private key
  age_secret_name = "sops-age"

  # Namespace to install Flux
  flux_namespace = "flux-system"
  # Enable extra components 'image-reflector-controller' and 'image-automation-controller'
  flux_enable_image_automation = true
}

generate "provider" {
  path      = "providers_config.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "helm" {
  kubernetes = {
    ${indent(4, local.kubernetes_provider_attrs)}
  }
}

provider "kubernetes" {
  ${indent(2, local.kubernetes_provider_attrs)}
}
EOF
}


generate "backend_local" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  disable   = !local.backend_local_enabled
  contents  = !local.backend_local_enabled ? "" : <<-EOF
    terraform {
      backend "local" {
        path = "${get_terragrunt_dir()}${trim(local.backend_config.local.path_prefix, "/")}/terraform.tfstate"
      }
    }
  EOF
}

generate "backend_s3" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  disable   = !local.backend_s3_enabled
  contents  = !local.backend_s3_enabled ? "" : <<-EOF
    terraform {
      backend "s3" {
        access_key = "${local.backend_config.s3.access_key}"
        secret_key = "${local.backend_config.s3.secret_key}"
        region     = "${local.backend_config.s3.region}"
        bucket     = "${local.backend_config.s3.bucket}"
        key        = "${trim(local.backend_config.s3.object_prefix, "/")}/${path_relative_to_include()}/terraform.tfstate"
      }
    }
  EOF
}


generate "backend_s3_compatible" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  disable   = !local.backend_s3_compatible_enabled
  contents  = !local.backend_s3_compatible_enabled ? "" : <<-EOF
    terraform {
      backend "s3" {
        endpoints = {
          s3 = "${local.backend_config.s3.endpoint}"
        }
        access_key                  = "${local.backend_config.s3.access_key}"
        secret_key                  = "${local.backend_config.s3.secret_key}"
        region                      = "${local.backend_config.s3.region}"
        bucket                      = "${local.backend_config.s3.bucket}"
        key                         = "${trim(local.backend_config.s3.object_prefix, "/")}/${path_relative_to_include()}/terraform.tfstate"
        encrypt                     = true
        skip_credentials_validation = true
        skip_metadata_api_check     = true
        skip_region_validation      = true
        skip_requesting_account_id  = true
        skip_s3_checksum            = true
      }
    }
  EOF
}
