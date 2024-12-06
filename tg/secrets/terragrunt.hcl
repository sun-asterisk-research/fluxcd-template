download_dir = "${get_repo_root()}/tg/.terragrunt-cache"

terraform {
  extra_arguments "apply_args" {
    commands = [
      "apply"
    ]

    arguments = !can(index(["1", "true", "yes", "y"], get_env("NO_AUTO_APPROVE", ""))) ? [
      "-auto-approve",
    ] : []
  }
}

inputs = {
  config_path = "${get_repo_root()}/sops.yaml"
}
