locals {
  tg_root_dir = "${get_repo_root()}/tg"

  backend_tfvars_files = [for file in [
    "${get_parent_terragrunt_dir()}/backend.default.tfvars",
    "${get_parent_terragrunt_dir()}/backend.tfvars",
    "${get_parent_terragrunt_dir()}/backend.tfvars.json"
  ] : file if fileexists(file)]

  backend_config = merge({
    type = "local"

    local = {
      path_prefix = ""
    }

    s3 = {}
  }, [
    for file in local.backend_tfvars_files : jsondecode(read_tfvars_file(file))
  ]...)

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

  after_hook "after_bootstrap" {
    commands = [
      "apply",
    ]

    execute = [
      "sh",
      "-c",
      <<-EOF
      git pull --ff-only $TF_VAR_git_remote $TF_VAR_git_branch
      EOF
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
