MODULES_SOURCE_BASE_URL ?= git::git@github.com:sun-asterisk-research/flux-tf.git//modules
MODULES_SOURCE_REF ?= a786ef2205ae342285a27a00b9eaa63183549607

CLUSTER ?= production

ifdef LOCAL_MODULES_SOURCE
	BOOTSTRAP_TG_SOURCE := $(LOCAL_MODULES_SOURCE)/bootstrap
	DECRYPT_TG_SOURCE := $(LOCAL_MODULES_SOURCE)/sops_decrypt
	ENCRYPT_TG_SOURCE := $(LOCAL_MODULES_SOURCE)/sops_encrypt
else
	BOOTSTRAP_TG_SOURCE := $(MODULES_SOURCE_BASE_URL)/bootstrap?ref=$(MODULES_SOURCE_REF)
	DECRYPT_TG_SOURCE := $(MODULES_SOURCE_BASE_URL)/sops_decrypt?ref=$(MODULES_SOURCE_REF)
	ENCRYPT_TG_SOURCE := $(MODULES_SOURCE_BASE_URL)/sops_encrypt?ref=$(MODULES_SOURCE_REF)
endif

export PATH := $(shell pwd)/.bin:$(PATH)
export DEBUG ?= false
export TG_PROVIDER_CACHE ?= true
export NO_AUTO_APPROVE ?= false
export COMMAND ?= apply

bootstrap:
ifndef CLUSTER
	$(error CLUSTER is undefined)
endif
	@TG_SOURCE=$(BOOTSTRAP_TG_SOURCE) ./scripts/bootstrap.sh "$(COMMAND)" "$(CLUSTER)"

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
	@TG_SOURCE=$(DECRYPT_TG_SOURCE) ./scripts/decrypt.sh $(COMMAND)

encrypt:
	@TG_SOURCE=$(ENCRYPT_TG_SOURCE) ./scripts/encrypt.sh $(COMMAND)

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
	@KS_FILE="./clusters/$(CLUSTER)/$(KS).yaml"; \
	KS_PATH="$(shell yq -r '.spec.path' "./clusters/$(CLUSTER)/$(KS).yaml")"; \
	IGNORE_PATHS=$(shell [ -n "$(PATHS)" ] && echo "--ignore-paths='*,$(shell echo $(PATHS) | sed 's/[^,][^,]*/\!&/g')'"); \
	flux build kustomization $(notdir $(KS)) --kustomization-file "$$KS_FILE" --path "$$KS_PATH" $$IGNORE_PATHS --dry-run | yq

.PHONY: apps infrastructure rbac

apps:
	@$(MAKE) -s build KS=apps

infrastructure:
	@$(MAKE) -s build KS=infrastructure

rbac:
	@$(MAKE) -s build KS=rbac

install-tools: ONLY_MISSING ?= false
install-tools:
	@./scripts/install-tools.sh
