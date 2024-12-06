include "root" {
  path =   find_in_parent_folders()
  expose = true
}

terraform {
  source = "git::git@github.com:sun-asterisk-research/flux-tf.git//modules/sops_encrypt?depth=1"
}
