SHELL := /bin/bash

# All Makefile variable are available as environment variables during target executions
.EXPORT_ALL_VARIABLES:

KCM_NAMESPACE ?= k0rdent
KCM_REPO ?= oci://ghcr.io/k0rdent/kcm/charts/hmc
KCM_VERSION ?= 0.0.6
KCM_MANAGEMENT_OBJECT_NAME = hmc
KCM_ACCESS_MANAGEMENT_OBJECT_NAME = hmc

TESTING_NAMESPACE ?= k0rdent
TARGET_NAMESPACE ?= blue

KIND_CLUSTER_NAME ?= k0rdent-management-local
KIND_KUBECTL_CONTEXT = kind-$(KIND_CLUSTER_NAME)

OPENSSL_DOCKER_IMAGE ?= alpine/openssl:3.3.2

AWS_REGION ?= us-west-2

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk command is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9.-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

# Checks if environment variable is set
.check-variable-%:
	@if [ "$($(var_name))" = "" ]; then\
		echo "Please define the $(var_description) with the $(var_name) variable";\
		exit 1;\
	fi

##@ Binaries

OS=$(shell uname | tr A-Z a-z)
ifeq ($(shell uname -m),x86_64)
	ARCH=amd64
else
	ARCH=arm64
endif

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	@mkdir -p $(LOCALBIN)

KIND ?= PATH=$(LOCALBIN):$(PATH) kind
KIND_VERSION ?= 0.25.0

HELM ?= PATH=$(LOCALBIN):$(PATH) helm
HELM_VERSION ?= v3.15.1

YQ ?= PATH=$(LOCALBIN):$(PATH) yq
YQ_VERSION ?= v4.44.6

KUBECTL ?= PATH=$(LOCALBIN):$(PATH) kubectl

DOCKER_VERSION ?= 27.4.1

# installs binary locally
$(LOCALBIN)/%: $(LOCALBIN)
	@curl -sLo $(LOCALBIN)/$(binary) $(url);\
		chmod +x $(LOCALBIN)/$(binary);

# checks if the binary exists in the PATH and installs it locally otherwise
.check-binary-%:
	@(which "$(binary)" $ > /dev/null || test -f $(LOCALBIN)/$(binary)) \
		|| (echo "Can't find the $(binary) in path, installing it locally" && make $(LOCALBIN)/$(binary))

.check-binary-docker:
	@if ! which docker $ > /dev/null; then \
		if [ "$(OS)" = "linux" ]; then \
			curl -sLO https://download.docker.com/linux/static/stable/$(shell uname -m)/docker-$(DOCKER_VERSION).tgz;\
			tar xzvf docker-$(DOCKER_VERSION).tgz; \
			sudo cp docker/* /usr/bin/ ; \
			echo "Starting docker daemon..." ; \
			sudo dockerd > /dev/null 2>&1 & sudo groupadd docker ; \
			sudo usermod -aG docker $(shell whoami) ; \
			newgrp docker ; \
			echo "Docker engine installed and started"; \
		else \
			echo "Please install docker before proceeding. If your work on machine with MacOS, check this installation guide: https://docs.docker.com/desktop/setup/install/mac-install/" && exit 1; \
		fi; \
	fi;

%kind: binary = kind
%kind: url = "https://kind.sigs.k8s.io/dl/v$(KIND_VERSION)/kind-$(OS)-$(ARCH)"
%kubectl: binary = kubectl
%kubectl: url = "https://dl.k8s.io/release/$(shell curl -L -s https://dl.k8s.io/release/stable.txt)/bin/$(OS)/$(ARCH)/kubectl"
%helm: binary = helm
%yq: binary = yq
%yq: url = "https://github.com/mikefarah/yq/releases/download/$(YQ_VERSION)/yq_$(OS)_$(ARCH)"

.PHONY: kind
kind: $(LOCALBIN)/kind ## Install kind binary locally if necessary

.PHONY: helm
helm: $(LOCALBIN)/helm ## Install helm binary locally if necessary
HELM_INSTALL_SCRIPT ?= "https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3"
$(LOCALBIN)/helm: | $(LOCALBIN)
	rm -f $(LOCALBIN)/helm-*
	curl -s --fail $(HELM_INSTALL_SCRIPT) | USE_SUDO=false HELM_INSTALL_DIR=$(LOCALBIN) DESIRED_VERSION=$(HELM_VERSION) BINARY_NAME=helm PATH="$(LOCALBIN):$(PATH)" bash


##@ General Setup

# Local management cluster
KIND_CLUSTER_CONFIG_PATH ?= $(LOCALBIN)/kind-cluster.yaml
$(KIND_CLUSTER_CONFIG_PATH): $(LOCALBIN)
	@cat setup/kind-cluster.yaml | envsubst > $(KIND_CLUSTER_CONFIG_PATH)

.PHONY: bootstrap-kind-cluster
bootstrap-kind-cluster: .check-binary-docker .check-binary-kind .check-binary-kubectl
bootstrap-kind-cluster: ## Provision local kind cluster
	@if $(KIND) get clusters | grep -q $(KIND_CLUSTER_NAME); then\
		echo "$(KIND_CLUSTER_NAME) kind cluster already installed";\
	else\
		rm -rf $(KIND_CLUSTER_CONFIG_PATH); \
		make $(KIND_CLUSTER_CONFIG_PATH); \
		$(KIND) create cluster --name=$(KIND_CLUSTER_NAME) --config=$(KIND_CLUSTER_CONFIG_PATH);\
	fi
	@$(KUBECTL) config use-context $(KIND_KUBECTL_CONTEXT)

# Deploy k0rdent operator
.PHONY: deploy-k0rdent
deploy-k0rdent: .check-binary-helm ## Deploy k0rdent to the management cluster
	$(HELM) install kcm $(KCM_REPO) --version $(KCM_VERSION) -n $(KCM_NAMESPACE) --create-namespace

.PHONY: watch-k0rdent-deployment
watch-k0rdent-deployment: .check-binary-kubectl
watch-k0rdent-deployment: ## Monitor k0rdent deployment
	@while true; do\
		if $(KUBECTL) get management $(KCM_MANAGEMENT_OBJECT_NAME) > /dev/null 2>&1; then \
				echo "Status of the k0rdent components installation: "; \
				$(KUBECTL) get management $(KCM_MANAGEMENT_OBJECT_NAME) -o go-template='{{range $$key, $$value := .status.components}}{{$$key}}: {{if $$value.success}}{{$$value.success}}{{else}}{{$$value.error}}{{end}}{{"\n"}}{{end}}'; \
				echo ; \
		else \
			echo "Waiting when k0rdent creates management object..."; \
		fi; \
		sleep 3; \
	done;

# Setup Helm registry and push charts with custom Cluster and Service templates
TEMPLATES_DIR := templates
TEAMPLATES = $(patsubst $(TEMPLATES_DIR)/%,%,$(wildcard $(TEMPLATES_DIR)/*))
TEMPLATE_FOLDERS = $(patsubst $(TEMPLATES_DIR)/%,%,$(wildcard $(TEMPLATES_DIR)/*))
CHARTS_PACKAGE_DIR ?= $(LOCALBIN)/charts
$(CHARTS_PACKAGE_DIR): | $(LOCALBIN)
	rm -rf $(CHARTS_PACKAGE_DIR)
	mkdir -p $(CHARTS_PACKAGE_DIR)

HELM_REGISTRY_INTERNAL_PORT ?= 5000
HELM_REGISTRY_EXTERNAL_PORT ?= 30500
REGISTRY_REPO ?= oci://127.0.0.1:$(HELM_REGISTRY_EXTERNAL_PORT)/helm-charts

.PHONY: helm-package
helm-package: $(CHARTS_PACKAGE_DIR) .check-binary-helm
	@make $(patsubst %,package-%-tmpl,$(TEMPLATE_FOLDERS))

lint-chart-%:
	$(HELM) dependency update $(TEMPLATES_SUBDIR)/$*
	$(HELM) lint --strict $(TEMPLATES_SUBDIR)/$*

package-%-tmpl:
	@make TEMPLATES_SUBDIR=$(TEMPLATES_DIR)/$* $(patsubst %,package-chart-%,$(shell find $(TEMPLATES_DIR)/$* -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))

package-chart-%: lint-chart-%
	$(HELM) package --destination $(CHARTS_PACKAGE_DIR) $(TEMPLATES_SUBDIR)/$*

.PHONY: helm-push
helm-push: helm-package
	@for chart in $(CHARTS_PACKAGE_DIR)/*.tgz; do \
		$(HELM) push "$$chart" $(REGISTRY_REPO); \
	done

apply-helmrepo: SHOW_DIFF = false
apply-helmrepo: template_path = setup/helmRepository.yaml
apply-helmrepo: ## Deploy local helm repository and register it in k0rdent

.PHONY: push-helm-charts
push-helm-charts: .check-binary-kubectl
push-helm-charts: ## Push helm charts with custom Cluster and Service templates
	@while true; do\
		if $(KUBECTL) -n $(TESTING_NAMESPACE) get deploy helm-registry; then \
			if [[ $$($(KUBECTL) -n $(TESTING_NAMESPACE) get deploy helm-registry -o jsonpath={.status.readyReplicas}) > 0 ]]; then \
				break; \
			fi; \
		fi; \
		echo "Waiting when the helm registry be ready..."; \
		sleep 3; \
	done;
	@make helm-push

##@ Infra Setup

get-creds-%: .check-binary-kubectl
	@$(KUBECTL) -n $(TESTING_NAMESPACE) get credentials $(creds_name)

# AWS
.%-aws-access-key: var_name = AWS_ACCESS_KEY_ID
.%-aws-access-key: var_description = AWS access key ID
.%-aws-secret-access-key: var_name = AWS_SECRET_ACCESS_KEY
.%-aws-secret-access-key: var_description = AWS secret access key

apply-aws-creds: SHOW_DIFF = false
apply-aws-creds: template_path = setup/aws-credentials.yaml
apply-aws-creds: .check-variable-aws-access-key .check-variable-aws-secret-access-key
apply-aws-creds: ## Setup AWS credentials

get-creds-aws: creds_name = aws-cluster-identity-cred
get-creds-aws: ## Get AWS credentials info

# Azure
.%-azure-sp-password: var_name = AZURE_SP_PASSWORD
.%-azure-sp-password: var_description = Azure Service Principal password
.%-azure-sp-app-id: var_name = AZURE_SP_APP_ID
.%-azure-sp-app-id: var_description = Azure Service Principal App ID
.%-azure-sp-tenant-id: var_name = AZURE_SP_TENANT_ID
.%-azure-sp-tenant-id: var_description = Azure Service Principal Tenant ID
.%-azure-sp-subscription-id: var_name = AZURE_SUBSCRIPTION_ID
.%-azure-sp-subscription-id: var_description = Azure Subscription ID

apply-azure-creds: SHOW_DIFF = false
apply-azure-creds: template_path = setup/azure-credentials.yaml
apply-azure-creds: .check-variable-azure-sp-password .check-variable-azure-sp-app-id .check-variable-azure-sp-tenant-id
apply-azure-creds: ## Setup Azure credentials

get-creds-azure: creds_name = azure-cluster-identity-cred
get-creds-azure: ## Get Azure credentials info

## Common targets and functions
UNIQUE_SUFFIX = $(patsubst %,-%,$(USERNAME))
FULL_CLUSTER_NAME = $(NAMESPACE)-$(PROVIDER)-$(CLUSTERNAME)$(UNIQUE_SUFFIX)

TEMP_DIR = $(LOCALBIN)/temp
$(TEMP_DIR): $(LOCALBIN)
	@mkdir -p $(TEMP_DIR)

apply-%: NAMESPACE = $(TESTING_NAMESPACE)
apply-%: SHOW_DIFF = true
apply-%: .check-binary-kubectl
	@if [[ "$$SHOW_DIFF" == "true" ]]; then \
		echo "Applying changes: "; \
		envsubst < $(template_path) | KUBECTL_EXTERNAL_DIFF="diff --color -N -u" $(KUBECTL) diff  -f - || true; \
	fi
	@envsubst < $(template_path) | $(KUBECTL) apply -f -

watch-%: NAMESPACE = $(TESTING_NAMESPACE)
watch-%: .check-binary-kubectl
watch-%:
	@$(KUBECTL) get -n $(NAMESPACE) clusterdeployment $(FULL_CLUSTER_NAME) --watch

KUBECONFIGS_DIR = $(shell pwd)/kubeconfigs
$(KUBECONFIGS_DIR):
	@mkdir -p $(KUBECONFIGS_DIR)

get-kubeconfig-%: NAMESPACE = $(TESTING_NAMESPACE)
get-kubeconfig-%: .check-binary-kubectl
	@$(KUBECTL) -n $(NAMESPACE) get secret $(FULL_CLUSTER_NAME)-kubeconfig -o jsonpath='{.data.value}' | base64 -d > $(KUBECONFIGS_DIR)/$(NAMESPACE)-aws-$(CLUSTERNAME).kubeconfig

# COMMAND is the yq expression that will be applied to the existing AccessManagement object
# If the command that implements this template has any credential_name, cluster_template_chain_name or service_template_chain_name variables, it will be added to the AccessManagement object:
approve-%: COMMAND = .spec.accessRules[0].targetNamespaces.list |= ((. // []) + "$(TARGET_NAMESPACE)" | unique)$(patsubst %, | .spec.accessRules[0].credentials |= ((. // []) + "%" | unique),$(credential_name))$(patsubst %, | .spec.accessRules[0].clusterTemplateChains |= ((. // []) + "%" | unique),$(cluster_template_chain_name))$(patsubst %, | .spec.accessRules[0].serviceTemplateChains |= ((. // []) + "%" | unique),$(service_template_chain_name))
approve-%: .check-binary-yq $(TEMP_DIR)
	@$(KUBECTL) -n $(TESTING_NAMESPACE) get AccessManagement $(KCM_ACCESS_MANAGEMENT_OBJECT_NAME) -o yaml | \
		$(YQ) '$(COMMAND)' > $(TEMP_DIR)/$(KCM_ACCESS_MANAGEMENT_OBJECT_NAME)-access-management.yaml
	@template_path=$(TEMP_DIR)/$(KCM_ACCESS_MANAGEMENT_OBJECT_NAME)-access-management.yaml make apply-accessmanagement

get-yaml-%: NAMESPACE = $(TESTING_NAMESPACE)
get-yaml-%: .check-binary-kubectl
	@$(KUBECTL) -n $(NAMESPACE) get $(TYPE) $(OBJECT_NAME) -o yaml

get-available-upgrades-%: .check-binary-kubectl
	@$(KUBECTL) -n $(NAMESPACE) get clusterdeployment.hmc.mirantis.com -o go-template='{{ range $$_,$$cluster := .items }}Cluster {{ $$cluster.metadata.name}} available upgrades: {{"\n"}}{{ range $$_,$$upgrade := $$cluster.status.availableUpgrades}}{{"  - "}}{{ $$upgrade }}{{"\n"}}{{ end }}{{"\n"}}{{ end }}'


##@ Demo 1

apply-clustertemplate-demo-aws-standalone-cp-0.0.1: SHOW_DIFF = false
apply-clustertemplate-demo-aws-standalone-cp-0.0.1: template_path = templates/cluster/demo-aws-standalone-cp-0.0.1.yaml
apply-clustertemplate-demo-aws-standalone-cp-0.0.1: ## Deploy custom demo-aws-standalone-cp-0.0.1 ClusterTemplate

apply-clustertemplate-demo-azure-standalone-cp-0.0.1: SHOW_DIFF = false
apply-clustertemplate-demo-azure-standalone-cp-0.0.1: template_path = templates/cluster/demo-azure-standalone-cp-0.0.1.yaml
apply-clustertemplate-demo-azure-standalone-cp-0.0.1: ## Deploy custom demo-azure-standalone-cp-0.0.1 ClusterTemplate

apply-cluster-deployment-aws-test1-0.0.1: CLUSTERNAME = test1
apply-cluster-deployment-aws-test1-0.0.1: template_path = clusterDeployments/aws/0.0.1.yaml
apply-cluster-deployment-aws-test1-0.0.1: ## Deploy cluster deployment test1 version 0.0.1 to AWS

apply-cluster-deployment-azure-test1-0.0.1: CLUSTERNAME = test1
apply-cluster-deployment-azure-test1-0.0.1: template_path = clusterDeployments/azure/1-0.0.1.yaml
apply-cluster-deployment-azure-test1-0.0.1: .check-variable-azure-sp-subscription-id
apply-cluster-deployment-azure-test1-0.0.1: ## Deploy cluster deployment test1 version 0.0.1 to Azure

watch-aws-test1: CLUSTERNAME = test1
watch-aws-test1: PROVIDER = aws
watch-aws-test1: ## Monitor the provisioning process of the cluster deployment test1 in AWS

watch-azure-test1: CLUSTERNAME = test1
watch-azure-test1: PROVIDER = azure
watch-azure-test1: ## Monitor the provisioning process of the cluster deployment test1 in Azure

get-kubeconfig-aws-test1: CLUSTERNAME = test1
get-kubeconfig-aws-test1: PROVIDER = aws
get-kubeconfig-aws-test1: ## Get kubeconfig for the cluster test1

apply-cluster-deployment-aws-test2-0.0.1: CLUSTERNAME = test2
apply-cluster-deployment-aws-test2-0.0.1: template_path = clusterDeployments/aws/0.0.1.yaml
apply-cluster-deployment-aws-test2-0.0.1: ## Deploy cluster deployment test2 version 0.0.1 to AWS

apply-cluster-deployment-azure-test2-0.0.1: CLUSTERNAME = test2
apply-cluster-deployment-azure-test2-0.0.1: template_path = clusterDeployments/azure/1-0.0.1.yaml
apply-cluster-deployment-azure-test2-0.0.2: .check-variable-azure-sp-subscription-id
apply-cluster-deployment-azure-test2-0.0.1: ## Deploy cluster deployment test2 version 0.0.1 to Azure

watch-aws-test2: CLUSTERNAME = test2
watch-aws-test2: PROVIDER = aws
watch-aws-test2: ## Monitor the provisioning process of the cluster deployment test2 in AWS

watch-azure-test2: CLUSTERNAME = test2
watch-azure-test2: PROVIDER = azure
watch-azure-test2: ## Monitor the provisioning process of the cluster deployment test2 in Azure

get-kubeconfig-aws-test2: CLUSTERNAME = test2
get-kubeconfig-aws-test2: PROVIDER = aws
get-kubeconfig-aws-test2: ## Get kubeconfig for the cluster test2

##@ Demo 2

apply-clustertemplate-demo-aws-standalone-cp-0.0.2: SHOW_DIFF = false
apply-clustertemplate-demo-aws-standalone-cp-0.0.2: template_path = templates/cluster/demo-aws-standalone-cp-0.0.2.yaml
apply-clustertemplate-demo-aws-standalone-cp-0.0.2: ## Deploy custom demo-aws-standalone-cp-0.0.2 ClusterTemplate

apply-clustertemplate-demo-azure-standalone-cp-0.0.2: SHOW_DIFF = false
apply-clustertemplate-demo-azure-standalone-cp-0.0.2: template_path = templates/cluster/demo-azure-standalone-cp-0.0.2.yaml
apply-clustertemplate-demo-azure-standalone-cp-0.0.2: ## Deploy custom demo-azure-standalone-cp-0.0.2 ClusterTemplate

get-available-upgrades-k0rdent: NAMESPACE = $(TESTING_NAMESPACE)
get-available-upgrades-k0rdent: ## Get available upgrades for all cluster deployments

apply-cluster-deployment-aws-test1-0.0.2: CLUSTERNAME = test1
apply-cluster-deployment-aws-test1-0.0.2: template_path = clusterDeployments/aws/0.0.2.yaml
apply-cluster-deployment-aws-test1-0.0.2: ## Upgrade cluster deployment test1 to version 0.0.2

apply-cluster-deployment-azure-test1-0.0.2: CLUSTERNAME = test1
apply-cluster-deployment-azure-test1-0.0.2: template_path = clusterDeployments/azure/1-0.0.2.yaml
apply-cluster-deployment-azure-test1-0.0.2: .check-variable-azure-sp-subscription-id
apply-cluster-deployment-azure-test1-0.0.2: ## Upgrade cluster deployment test1 to version 0.0.2

##@ Demo 3

apply-servicetemplate-demo-ingress-nginx-4.11.0: SHOW_DIFF = false
apply-servicetemplate-demo-ingress-nginx-4.11.0: template_path = templates/service/demo-ingress-nginx-4.11.0.yaml
apply-servicetemplate-demo-ingress-nginx-4.11.0: ## Deploy custom demo-ingress-nginx-4.11.0 ServiceTemplate

apply-cluster-deployment-aws-test1-ingress: CLUSTERNAME = test1
apply-cluster-deployment-aws-test1-ingress: PROVIDER = aws
apply-cluster-deployment-aws-test1-ingress: DEPLOYMENT_VERSION = $(patsubst demo-aws-standalone-cp-%,%,$(shell $(KUBECTL) -n $(NAMESPACE) get clusterdeployment.hmc.mirantis.com $(FULL_CLUSTER_NAME) -o jsonpath='{.spec.template}'))
apply-cluster-deployment-aws-test1-ingress: template_path = clusterDeployments/aws/$(DEPLOYMENT_VERSION)-ingress.yaml
apply-cluster-deployment-aws-test1-ingress: ## Deploy ingress service to the cluster deployment test1 in AWS

apply-cluster-deployment-aws-test2-ingress: CLUSTERNAME = test2
apply-cluster-deployment-aws-test2-ingress: PROVIDER = aws
apply-cluster-deployment-aws-test2-ingress: DEPLOYMENT_VERSION = $(patsubst demo-aws-standalone-cp-%,%,$(shell $(KUBECTL) -n $(NAMESPACE) get clusterdeployment.hmc.mirantis.com $(FULL_CLUSTER_NAME) -o jsonpath='{.spec.template}'))
apply-cluster-deployment-aws-test2-ingress: template_path = clusterDeployments/aws/$(DEPLOYMENT_VERSION)-ingress.yaml
apply-cluster-deployment-aws-test2-ingress: ## Deploy ingress service to the cluster deployment test2 in AWS

get-yaml-clusterdeployment-aws-test2: TYPE = clusterdeployment.hmc.mirantis.com
get-yaml-clusterdeployment-aws-test2: CLUSTERNAME = test2
get-yaml-clusterdeployment-aws-test2: PROVIDER = aws
get-yaml-clusterdeployment-aws-test2: OBJECT_NAME = $(FULL_CLUSTER_NAME)
get-yaml-clusterdeployment-aws-test2: ## Get test2 ClusterDeployment object in yaml format

##@ Demo 4

apply-servicetemplate-demo-kyverno-3.2.6: SHOW_DIFF = false
apply-servicetemplate-demo-kyverno-3.2.6: template_path = templates/service/demo-kyverno-3.2.6.yaml
apply-servicetemplate-demo-kyverno-3.2.6: ## Deploy custom demo-kyverno-3.2.6

apply-multiclusterservice-global-kyverno: template_path = MultiClusterServices/1-global-kyverno.yaml
apply-multiclusterservice-global-kyverno: ## Deploy MultiClusterService global-kyverno that installs kyverno service to all cluster deployments

get-yaml-milticlasterservice-global-kyverno: TYPE = multiclusterservice.hmc.mirantis.com
get-yaml-milticlasterservice-global-kyverno: OBJECT_NAME = global-kyverno
get-yaml-milticlasterservice-global-kyverno: ## Get global-kyverno MultiClusterService object in yaml format

##@ Demo 5

CERTS_DIR = $(shell pwd)/certs
CERTS_CA_DIR = $(CERTS_DIR)/ca
$(CERTS_CA_DIR):
	@mkdir -p $(CERTS_CA_DIR)

$(CERTS_CA_DIR)/ca.crt: $(CERTS_CA_DIR)
	@docker cp $(KIND_CLUSTER_NAME)-control-plane:/etc/kubernetes/pki/ca.crt $@

$(CERTS_CA_DIR)/ca.key: $(CERTS_CA_DIR)
	@docker cp $(KIND_CLUSTER_NAME)-control-plane:/etc/kubernetes/pki/ca.key $@

PLATFORM_ENGINEER_CERTS_DIR = $(CERTS_DIR)/platform-engineer1
$(PLATFORM_ENGINEER_CERTS_DIR):
	@mkdir -p $(PLATFORM_ENGINEER_CERTS_DIR)

$(PLATFORM_ENGINEER_CERTS_DIR)/platform-engineer1.key: $(PLATFORM_ENGINEER_CERTS_DIR)
	@docker run -v $(CERTS_DIR):/certs $(OPENSSL_DOCKER_IMAGE) genrsa -out /certs/platform-engineer1/platform-engineer1.key 2048

$(PLATFORM_ENGINEER_CERTS_DIR)/platform-engineer1.csr: $(PLATFORM_ENGINEER_CERTS_DIR) $(PLATFORM_ENGINEER_CERTS_DIR)/platform-engineer1.key
	@docker run -v $(CERTS_DIR):/certs $(OPENSSL_DOCKER_IMAGE) req -new -key /certs/platform-engineer1/platform-engineer1.key -out /certs/platform-engineer1/platform-engineer1.csr -subj '/CN=platform-engineer1/O=$(TARGET_NAMESPACE)'

$(PLATFORM_ENGINEER_CERTS_DIR)/platform-engineer1.crt: $(PLATFORM_ENGINEER_CERTS_DIR) $(PLATFORM_ENGINEER_CERTS_DIR)/platform-engineer1.csr $(CERTS_CA_DIR)/ca.crt $(CERTS_CA_DIR)/ca.key
	@docker run -v $(CERTS_DIR):/certs $(OPENSSL_DOCKER_IMAGE) x509 -req -in /certs/platform-engineer1/platform-engineer1.csr -CA /certs/ca/ca.crt -CAkey /certs/ca/ca.key -CAcreateserial -out /certs/platform-engineer1/platform-engineer1.crt -days 360

.PHONY: create-target-namespace-rolebindings
create-target-namespace-rolebindings: .check-binary-kubectl
create-target-namespace-rolebindings: ## Create RBAC configuration for users that should have the access only to the blue namespace
	@kubectl get namespace $(TARGET_NAMESPACE) > /dev/null 2>&1 || kubectl create namespace $(TARGET_NAMESPACE)
	@envsubst < rolebindings.yaml | kubectl apply -f -

.PHONY: generate-platform-engineer1-kubeconfig
generate-platform-engineer1-kubeconfig: USER_NAME = platform-engineer1
generate-platform-engineer1-kubeconfig: clean-certs
generate-platform-engineer1-kubeconfig: ## Create Platform Engineer user that has access only to the blue namespace
	@make $(CERTS_DIR)/$(USER_NAME)/$(USER_NAME).crt
	@USER_CRT=$$(cat $(CERTS_DIR)/$(USER_NAME)/$(USER_NAME).crt | base64 | tr -d '\n\r') \
		USER_KEY=$$(cat $(CERTS_DIR)/$(USER_NAME)/$(USER_NAME).key | base64 | tr -d '\n\r')  \
		CA_CRT=$$(cat $(CERTS_CA_DIR)/ca.crt | base64 | tr -d '\n\r') \
		CLUSTER_HOST_PORT=$$(docker port $(KIND_CLUSTER_NAME)-control-plane 6443) \
		envsubst < certs/kubeconfig-template.yaml > certs/$(USER_NAME)/kubeconfig.yaml
	@echo "Config exported to certs/$(USER_NAME)/kubeconfig.yaml"

approve-clustertemplatechain-aws-standalone-cp-0.0.1: cluster_template_chain_name = demo-aws-standalone-cp-0.0.1
approve-clustertemplatechain-aws-standalone-cp-0.0.1: ## Approve ClusterTemplate demo-aws-standalone-cp-0.0.1 into the target namespace

approve-credential-aws: credential_name = aws-cluster-identity-cred
approve-credential-aws: ## Approve AWS Credentials into the target namespace

get-yaml-accessmanagement: TYPE = accessmanagement.hmc.mirantis.com
get-yaml-accessmanagement: OBJECT_NAME = $(KCM_MANAGEMENT_OBJECT_NAME)
get-yaml-accessmanagement: ## Get k0rdent AccessManagement object in yaml format

##@ Demo 6

apply-cluster-deployment-aws-dev1-0.0.1: CLUSTERNAME = dev1
apply-cluster-deployment-aws-dev1-0.0.1: template_path = clusterDeployments/aws/0.0.1.yaml
apply-cluster-deployment-aws-dev1-0.0.1: NAMESPACE = $(TARGET_NAMESPACE)
apply-cluster-deployment-aws-dev1-0.0.1: KUBECONFIG = certs/platform-engineer1/kubeconfig.yaml
apply-cluster-deployment-aws-dev1-0.0.1: ## Deploy cluster deployment AWS dev1 version 0.0.1 to the blue namespace as Platform Engineer

watch-aws-dev1: CLUSTERNAME = dev1
watch-aws-dev1: PROVIDER = aws
watch-aws-dev1: NAMESPACE = $(TARGET_NAMESPACE)
watch-aws-dev1: KUBECONFIG = certs/platform-engineer1/kubeconfig.yaml
watch-aws-dev1: ## Monitor the provisioning process of the AWS cluster deployment dev1 in blue namespace

get-kubeconfig-aws-dev1: CLUSTERNAME = dev1
get-kubeconfig-aws-dev1: NAMESPACE = $(TARGET_NAMESPACE)
get-kubeconfig-aws-dev1: PROVIDER = aws
get-kubeconfig-aws-dev1: KUBECONFIG = certs/platform-engineer1/kubeconfig.yaml
get-kubeconfig-aws-dev1: ## Get kubeconfig for the cluster dev1 in the blue namespace

##@ Demo 7

approve-clustertemplatechain-aws-standalone-cp-0.0.2: cluster_template_chain_name = demo-aws-standalone-cp-0.0.2 demo-aws-standalone-cp-0.0.1
approve-clustertemplatechain-aws-standalone-cp-0.0.2: ## Approve ClusterTemplate demo-aws-standalone-cp-0.0.2 into the target namespace

##@ Demo 8

get-available-upgrades-blue: NAMESPACE = $(TARGET_NAMESPACE)
get-available-upgrades-blue: ## Get available upgrades for all cluster deployments in the blue namespace

apply-cluster-deployment-aws-dev1-0.0.2: CLUSTERNAME = dev1
apply-cluster-deployment-aws-dev1-0.0.2: template_path = clusterDeployments/aws/0.0.2.yaml
apply-cluster-deployment-aws-dev1-0.0.2: NAMESPACE = $(TARGET_NAMESPACE)
apply-cluster-deployment-aws-dev1-0.0.2: KUBECONFIG = certs/platform-engineer1/kubeconfig.yaml
apply-cluster-deployment-aws-dev1-0.0.2: ## Upgrade cluster deployment dev1 in the blue namespace to version 0.0.2

##@ Demo 9

approve-servicetemplatechain-ingress-nginx-4.11.0: service_template_chain_name = demo-ingress-nginx-4.11.0
approve-servicetemplatechain-ingress-nginx-4.11.0: ## Approve ServiceTemplate into the target namespace

##@ Demo 10

apply-cluster-deployment-aws-dev1-ingress: CLUSTERNAME = dev1
apply-cluster-deployment-aws-dev1-ingress: NAMESPACE = $(TARGET_NAMESPACE)
apply-cluster-deployment-aws-dev1-ingress: PROVIDER = aws
apply-cluster-deployment-aws-dev1-ingress: DEPLOYMENT_VERSION = $(patsubst demo-aws-standalone-cp-%,%,$(shell $(KUBECTL) -n $(NAMESPACE) get clusterdeployment.hmc.mirantis.com $(FULL_CLUSTER_NAME) -o jsonpath='{.spec.template}'))
apply-cluster-deployment-aws-dev1-ingress: template_path = clusterDeployments/aws/$(DEPLOYMENT_VERSION)-ingress.yaml
apply-cluster-deployment-aws-dev1-ingress: KUBECONFIG = certs/platform-engineer1/kubeconfig.yaml
apply-cluster-deployment-aws-dev1-ingress: ## Deploy ingress service to the AWS cluster deployment dev1 in the blue namespace

get-yaml-clusterdeployment-aws-dev1: TYPE = clusterdeployment.hmc.mirantis.com
get-yaml-clusterdeployment-aws-dev1: CLUSTERNAME = dev1
get-yaml-clusterdeployment-aws-dev1: PROVIDER = aws
get-yaml-clusterdeployment-aws-dev1: NAMESPACE = $(TARGET_NAMESPACE)
get-yaml-clusterdeployment-aws-dev1: OBJECT_NAME = $(FULL_CLUSTER_NAME)
get-yaml-clusterdeployment-aws-dev1: KUBECONFIG = certs/platform-engineer1/kubeconfig.yaml
get-yaml-clusterdeployment-aws-dev1: ## Get dev1 ClusterDeployment object from the blue namespace in yaml format


##@ Cleanup

.PHONY: cleanup-clusters
cleanup-clusters: .check-binary-kubectl clean-certs
cleanup-clusters: ## Tear down managed cluster
	@if $(KIND) get clusters | grep -q $(KIND_CLUSTER_NAME); then \
		$(KUBECTL) --context=$(KIND_KUBECTL_CONTEXT) delete clusterdeployment.hmc.mirantis.com --all -A --wait=false 2>/dev/null || true; \
		while [[ $$($(KUBECTL) --context=$(KIND_KUBECTL_CONTEXT) get clusterdeployment.hmc.mirantis.com -A -o go-template='{{ len .items }}' 2>/dev/null || echo 0) > 0 ]]; do \
			echo "Waiting untill all cluster deployments are deleted..."; \
			sleep 3; \
		done; \
	fi

.PHONY: cleanup
cleanup: cleanup-clusters clean-certs clean-configs
cleanup: ## Tear down management cluster
	@if $(KIND) get clusters | grep -q $(KIND_CLUSTER_NAME); then\
		$(KIND) delete cluster --name=$(KIND_CLUSTER_NAME);\
	else\
		echo "Can't find kind cluster with the name $(KIND_CLUSTER_NAME)";\
	fi

.PHONY: clean-configs
clean-configs:
	@rm -rf $(KIND_CLUSTER_CONFIG_PATH)
	@rm -rf $(LOCALBIN)/charts
	@rm -rf $(KUBECONFIGS_DIR)/*.kubeconfig
	@rm -rf $(TEMP_DIR)

.PHONY: clean-certs
clean-certs:
	@rm -rf certs/ca
	@rm -rf certs/platform-engineer*
