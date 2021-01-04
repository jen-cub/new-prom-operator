
RELEASE := prometheus-stack
NAMESPACE := kube-system

CHART_NAME := prometheus-community/kube-prometheus-stack
CHART_VERSION ?= 10.3.2

DEV_CLUSTER ?= testrc
DEV_PROJECT ?= jendevops1
DEV_ZONE ?= australia-southeast1-c

.DEFAULT_TARGET: status

lint:
	@find . -type f -name '*.yml' | xargs yamllint
	@find . -type f -name '*.yaml' | xargs yamllint

init:
	helm3 repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm3 repo update

dev: lint init
ifndef CI
	$(error Please commit and push, this is intended to be run in a CI environment)
endif
	gcloud config set project $(DEV_PROJECT)
	gcloud container clusters get-credentials $(DEV_CLUSTER) --zone $(DEV_ZONE) --project $(DEV_PROJECT)
	helm3 upgrade --install --wait $(RELEASE) \
		--set grafana.adminPassword=$(DEV_GRAFANA_PW) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		-f values.yaml \
		--values env/dev/values.yaml \
		$(CHART_NAME)
	$(MAKE) history

prod: lint init
ifndef CI
	$(error Please commit and push, this is intended to be run in a CI environment)
endif
	gcloud config set project $(PROD_PROJECT)
	gcloud container clusters get-credentials $(PROD_PROJECT) --zone $(PROD_ZONE) --project $(PROD_PROJECT)
	-kubectl label namespace $(NAMESPACE)
	helm3 upgrade --install --force --wait $(RELEASE) \
		--namespace=$(NAMESPACE) \
		--version $(CHART_VERSION) \
		-f values.yaml \
		--values env/prod/values.yaml \
		$(CHART_NAME)
	$(MAKE) history

destroy:
	helm3 uninstall $(RELEASE) -n $(NAMESPACE)

history:
	helm3 history $(RELEASE) -n $(NAMESPACE) --max=5
