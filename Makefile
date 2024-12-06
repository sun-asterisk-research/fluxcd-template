MODULES_SOURCE_BASE_URL ?= git::git@github.com:sun-asterisk-research/flux-tf.git//modules
MODULES_SOURCE_REF ?= f5d55991c0c9604cc18c7f93321c0b5c2f43fd30

ifdef LOCAL_MODULES_SOURCE
	BOOTSTRAP_TERRAGRUNT_SOURCE := $(LOCAL_MODULES_SOURCE)/bootstrap
	DECRYPT_TERRAGRUNT_SOURCE := $(LOCAL_MODULES_SOURCE)/sops_decrypt
	ENCRYPT_TERRAGRUNT_SOURCE := $(LOCAL_MODULES_SOURCE)/sops_encrypt
else
	BOOTSTRAP_TERRAGRUNT_SOURCE := $(MODULES_SOURCE_BASE_URL)/bootstrap?ref=$(MODULES_SOURCE_REF)
	DECRYPT_TERRAGRUNT_SOURCE := $(MODULES_SOURCE_BASE_URL)/sops_decrypt?ref=$(MODULES_SOURCE_REF)
	ENCRYPT_TERRAGRUNT_SOURCE := $(MODULES_SOURCE_BASE_URL)/sops_encrypt?ref=$(MODULES_SOURCE_REF)
endif

export PATH := $(shell pwd)/.bin:$(PATH)
export DEBUG ?= false
export TERRAGRUNT_PROVIDER_CACHE ?= true
export NO_AUTO_APPROVE ?= false
export COMMAND ?= apply

bootstrap:
ifndef CLUSTER
	$(error CLUSTER is undefined)
endif
	@TERRAGRUNT_SOURCE=$(BOOTSTRAP_TERRAGRUNT_SOURCE) ./scripts/bootstrap.sh $(COMMAND) $(CLUSTER)

bootstrap-%:
	@$(MAKE) -s bootstrap CLUSTER=$*

cache-clear:
	rm -rf tg/.terragrunt-cache

cluster-init:
ifndef CLUSTER
	$(error CLUSTER is undefined)
endif
	@./scripts/cluster-init.sh $(CLUSTER)

decrypt:
	@TERRAGRUNT_SOURCE=$(DECRYPT_TERRAGRUNT_SOURCE) ./scripts/decrypt.sh $(COMMAND)

encrypt:
	@TERRAGRUNT_SOURCE=$(ENCRYPT_TERRAGRUNT_SOURCE) ./scripts/encrypt.sh $(COMMAND)

sops-add: TYPE=age
sops-add: GROUPS=human
sops-add:
	@./scripts/sops-add.sh '$(NAME)' '$(GROUPS)' '$(TYPE)' '$(REC)'

build:
ifndef KS
	$(error no KS provided)
endif
ifndef CLUSTER
	$(error no CLUSTER provided)
endif
ifndef NS
	flux build kustomization $(KS) --kustomization-file ./clusters/$(CLUSTER)/$(KS).yaml --path ./$(KS)/$(CLUSTER)/ --dry-run
else
	flux build kustomization $(KS) --kustomization-file ./clusters/$(CLUSTER)/$(KS).yaml --path ./$(KS)/$(CLUSTER)/ --dry-run | yq 'select(.metadata.namespace == "$(NS)" or (.kind == "Namespace" and .metadata.name == "$(NS)"))'
endif

.PHONY: apps infrastructure

apps:
	@$(MAKE) -s build KS=apps

infrastructure:
	@$(MAKE) -s build KS=infrastructure

install-tools: ONLY_MISSING ?= false
install-tools:
	@./scripts/install-tools.sh
