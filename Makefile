.DEFAULT_GOAL := build

# ocp
OPENSHIFT_MIRROR?=https://mirror.openshift.com/pub/openshift-v4
OCP_RELEASE_CHANNEL?=stable-4.10

# okd
OKD_MIRROR?=https://github.com/okd-project/okd/releases/download

# either okd or ocp
DEPLOYMENT_TYPE?=okd

# 4.11.0-0.okd-2022-12-02-145640
# 4.12.0-0.okd-2023-02-04-212953
# fixed release version
# OPENSHIFT_RELEASE?=none
OPENSHIFT_RELEASE?=4.12.0-0.okd-2023-02-04-212953

# image name
CONTAINER_NAME?=quay.io/slauger/hcloud-okd4
CONTAINER_TAG?=$(OPENSHIFT_RELEASE)

# coreos
ifeq ($(DEPLOYMENT_TYPE),ocp)
	COREOS_IMAGE=rhcos
else ifeq ($(DEPLOYMENT_TYPE),okd)
	COREOS_IMAGE=fcos
else
	$(error installer only supports ocp or okd)
endif

# Hetzner image location
IMAGE_LOCATION=$(shell egrep -o '"nbg1"|"fsn1"|"hel1"' /workspace/terraform/variables.tf | cut -d'"' -f2)

# terraform switches
BOOTSTRAP?=false
MODE?=apply

# # openshift version
# .PHONY: latest_version
# latest_version: latest_version_$(DEPLOYMENT_TYPE)

# .PHONY: latest_version_okd
# latest_version_okd:
# 	@curl -s -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/okd-project/okd/tags | jq -j -r .[0].name

# .PHONY: latest_version_ocp
# latest_version_ocp:
# 	@curl -s https://raw.githubusercontent.com/openshift/cincinnati-graph-data/master/channels/$(OCP_RELEASE_CHANNEL).yaml | egrep '(4\.[0-9]+\.[0-9]+)' | tail -n1 | cut -d" " -f2

# fetch
.PHONY: fetch
fetch: fetch_$(DEPLOYMENT_TYPE)

.PHONY: fetch_okd
fetch_okd:
	wget -O openshift-install-linux-$(OPENSHIFT_RELEASE).tar.gz $(OKD_MIRROR)/$(OPENSHIFT_RELEASE)/openshift-install-linux-$(OPENSHIFT_RELEASE).tar.gz
	wget -O openshift-client-linux-$(OPENSHIFT_RELEASE).tar.gz $(OKD_MIRROR)/$(OPENSHIFT_RELEASE)/openshift-client-linux-$(OPENSHIFT_RELEASE).tar.gz

.PHONY: fetch_ocp
fetch_ocp:
	wget -O openshift-install-linux-$(OPENSHIFT_RELEASE).tar.gz $(OPENSHIFT_MIRROR)/clients/ocp/$(OPENSHIFT_RELEASE)/openshift-install-linux-$(OPENSHIFT_RELEASE).tar.gz
	wget -O openshift-client-linux-$(OPENSHIFT_RELEASE).tar.gz $(OPENSHIFT_MIRROR)/clients/ocp/$(OPENSHIFT_RELEASE)/openshift-client-linux-$(OPENSHIFT_RELEASE).tar.gz

.PHONY: build
build:
	docker build --build-arg DEPLOYMENT_TYPE=$(DEPLOYMENT_TYPE) --build-arg OPENSHIFT_RELEASE=$(OPENSHIFT_RELEASE) -t $(CONTAINER_NAME):$(CONTAINER_TAG) .

.PHONY: test
test:
	docker run -v /var/run/docker.sock:/var/run/docker.sock -v $(shell pwd):/src:ro gcr.io/gcp-runtimes/container-structure-test:latest test --image $(CONTAINER_NAME):$(CONTAINER_TAG) --config /src/tests/image.tests.yaml

.PHONY: push
push:
	docker push $(CONTAINER_NAME):$(CONTAINER_TAG)

.PHONY: run
run:
	docker run -it --hostname openshift-toolbox --mount type=bind,source="$(shell pwd)",target=/workspace --mount type=bind,source="$(HOME)/.ssh,target=/root/.ssh" $(CONTAINER_NAME):$(CONTAINER_TAG) /bin/bash

.PHONY: generate_okd_configs
generate_okd_configs:
	(cd terraform && terraform init && terraform $(MODE) -var generate_okd_configs=true -target=module.installer && cd ..) && \
	mkdir -p config
	cp install-config.yaml config/install-config.yaml
	openshift-install create manifests --dir=config && \
	sleep 10 && \
	rsync -av config/ ignition && \
	openshift-install create ignition-configs --dir=ignition

# .PHONY: generate_okd_configs
# generate_okd_configs:
# 	(cd terraform && terraform init && terraform $(MODE) -var generate_okd_configs=true -target=module.installer && cd ..) && \
# 	mkdir -p config
# 	cp install-config.yaml config/install-config.yaml
# 	openshift-install create manifests --dir=config && \
# 	cp okd-configure-master-node-dns.yaml config/manifests/okd-configure-master-node-dns.yaml && \
# 	cp okd-configure-worker-node-dns.yaml config/manifests/okd-configure-worker-node-dns.yaml && \
# 	sleep 10 && \
# 	rsync -av config/ ignition && \
# 	openshift-install create ignition-configs --dir=ignition && \
# 	cp ignition/bootstrap.ign ignition/bootstrap-orig.ign && \
# 	cp ignition/master.ign ignition/master-orig.ign && \
# 	cp ignition/worker.ign ignition/worker-orig.ign && \
# 	jq --slurpfile other dns.json '.storage.files += $$other[].storage.files | .storage.links += $$other[].storage.links' ignition/bootstrap-orig.ign > ignition/bootstrap.ign && \
# 	jq '. * input' dns.json ignition/master-orig.ign > ignition/master.ign && \
# 	jq '. * input' dns.json ignition/worker-orig.ign > ignition/worker.ign && \
# 	rm -f ignition/*-orig.ign

# .PHONY: generate_okd_configs
# generate_okd_configs:
# 	(cd terraform && terraform init && terraform $(MODE) -var generate_okd_configs=true -target=module.installer && cd ..) && \
# 	mkdir -p config
# 	cp install-config.yaml config/install-config.yaml
# 	openshift-install create manifests --dir=config && \
# 	sleep 10 && \
# 	rsync -av config/ ignition && \
# 	openshift-install create ignition-configs --dir=ignition && \
# 	cp ignition/bootstrap.ign ignition/bootstrap-orig.ign && \
# 	cp ignition/master.ign ignition/master-orig.ign && \
# 	cp ignition/worker.ign ignition/worker-orig.ign && \
# 	jq --slurpfile other dns.json '.storage.files += $$other[].storage.files | .storage.links += $$other[].storage.links' ignition/bootstrap-orig.ign > ignition/bootstrap.ign && \
# 	jq '. * input' dns.json ignition/master-orig.ign > ignition/master.ign && \
# 	jq '. * input' dns.json ignition/worker-orig.ign > ignition/worker.ign && \
# 	rm -f ignition/*-orig.ign

# .PHONY: generate_manifests
# generate_manifests:
# 	mkdir -p config
# 	cp install-config.yaml config/install-config.yaml
# 	openshift-install create manifests --dir=config

# .PHONY: generate_ignition
# generate_ignition:
# 	rsync -av config/ ignition
# 	openshift-install create ignition-configs --dir=ignition

.PHONY: hcloud_image
hcloud_image:
	@if [ -z "$(HCLOUD_TOKEN)" ]; then echo "ERROR: HCLOUD_TOKEN is not set"; exit 1; fi
	@if [ -z "$(IMAGE_LOCATION)" ]; then echo "ERROR: IMAGE_LOCATION can't be determined"; exit 1; fi
	if [ "$(DEPLOYMENT_TYPE)" == "okd" ]; then (cd packer && packer build -var location=$(IMAGE_LOCATION) -var fcos_url=$(shell openshift-install coreos print-stream-json | jq -r '.architectures.x86_64.artifacts.qemu.formats."qcow2.xz".disk.location') hcloud-fcos.json); fi
	if [ "$(DEPLOYMENT_TYPE)" == "ocp" ]; then (cd packer && packer build -var location=$(IMAGE_LOCATION) -var rhcos_url=$(shell openshift-install coreos print-stream-json | jq -r '.architectures.x86_64.artifacts.qemu.formats."qcow2.gz".disk.location') hcloud-rhcos.json); fi

.PHONY: sign_csr
sign_csr:
	@if [ ! -f "ignition/auth/kubeconfig" ]; then echo "ERROR: ignition/auth/kubeconfig not found"; exit 1; fi
	bash -c "export KUBECONFIG=$(shell pwd)/ignition/auth/kubeconfig; oc get csr -o name | xargs oc adm certificate approve || true"

.PHONY: wait_bootstrap
wait_bootstrap:
	openshift-install --dir=ignition/ wait-for bootstrap-complete --log-level=debug

.PHONY: wait_completion
wait_completion:
	openshift-install --dir=ignition/ wait-for install-complete --log-level=debug

.PHONY: infrastructure
infrastructure:
	@if [ -z "$(HCLOUD_TOKEN)" ]; then echo "ERROR: HCLOUD_TOKEN is not set"; exit 1; fi
	(cd terraform && terraform init && terraform $(MODE) -var image=$(COREOS_IMAGE) -var bootstrap=$(BOOTSTRAP) -var generate_okd_configs=true)
	if [ "$(MODE)" == "apply" ]; then (cd ansible && ansible-playbook site.yml); fi

.PHONY: destroy
destroy:
	(cd terraform && terraform init && terraform destroy)
	(cd /workspace && rm -Rf config ignition install-config.yaml)
