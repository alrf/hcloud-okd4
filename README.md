![Docker Build](https://github.com/slauger/hcloud-okd4/workflows/Docker%20Build/badge.svg)


# hcloud-okd4

Deploy OKD4 (OpenShift) on Hetzner Cloud using Hashicorp Packer, Terraform, Ansible and Hetzner DNS.


## Current status

The Hetzner Cloud does not fulfill the I/O performance/latency requirements for etcd - even when using local SSDs (instead of ceph storage). This could result in different problems during the cluster bootstrap. You could check the I/O performance via `etcdctl check perf`.

Because of that OpenShift on hcloud is only suitable for small test environments. Please do not use it for production clusters.

## Architecture

- 3x Master Node (CX41)
- 6x Worker Nodes (CX41)
- 1x Node as Loadbalancer (CX21)
- 1x Bootstrap Node (CX41) - deleted after cluster bootstrap
- 1x Ignition Node (CX11) - deleted after cluster bootstrap
- secrets are stored in AWS Secrets Manager

## Preconditions/Requirements

### Configure (or create) Github OAuth App in Developer settings, for example:
```
Homepage URL
https://oauth-openshift.os-dev-hz.example.com

Authorization callback URL
https://oauth-openshift.os-dev-hz.example.com/oauth2callback/GitHub.com%YOUR%20Organization
```

### Create the Secrets in AWS Secrets Manager:
* `os-<environment>/github` (e.g. `os-dev-hz/github`) - OKD4 & Github OAuth integration (2 key/pairs should be created: `oauth_secret` as Key and `oauth_client` as Key)
* `os-<environment>/cluster` (e.g. `os-dev-hz/cluster`) - empty secret, it will be populated during the cluster bootstrapping  
`os-<environment>` MUST match with `cluster_name` variable.
* `hetzner/dns` - Hetzner DNS settings (3 key/pairs should be created: `api_key`, `zone_id`, `api_url` as Keys)
* `okd4/pullsecret` - PullSecret to pull Red Hat stuff for OKD

### Issue Letsencrypt wildcard certificate

First time the wildcard certificate should be manually requested for your domain (e.g. `*.os-dev-hz.example.com`).  
Later the certificate will be automatically renewed by the cronjob pipeline.  
Run the commands below from the toolbox container.  
```
curl https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh | sh -s -- --install-online -m dev@example.com
mkdir -p /workspace/acme
export HETZNER_Token=<YOUR_HCLOUD_TOKEN>
/root/.acme.sh/acme.sh --issue --force --ecc --server letsencrypt -d *.os-dev-hz.example.com --dns dns_hetzner --home /workspace/acme
## check certificate
openssl x509 -in /workspace/acme/*.os-dev-hz.example.com_ecc/*.os-dev-hz.example.com.cer -dates -noout
wget -P /workspace/acme https://letsencrypt.org/certs/lets-encrypt-r3.pem
wget -P /workspace/acme https://letsencrypt.org/certs/isrgrootx1.pem
openssl verify -CAfile <(cat /workspace/acme/isrgrootx1.pem /workspace/acme/lets-encrypt-r3.pem) /workspace/acme/*.os-dev-hz.example.com_ecc/*.os-dev-hz.example.com.cer
```

## Usage

### Set Version

Set a target version in Makefile.

```
OPENSHIFT_RELEASE?=4.12.0-0.okd-2023-04-16-041331
```

### Build toolbox container

To ensure that the we have a proper build environment, we create a toolbox container first.

```
make fetch ### will download OKD archives
make build
```

If you do not want to build the container by your own, it is also available on [quay.io](https://quay.io/repository/slauger/hcloud-okd4).

### Run toolbox

Use the following command to start the container.

```
make run
```

All the following commands will be executed inside the container. 

### Set required environment variables

Fill out the `terraform/terraform.auto.vars` file with your values:

```
cluster_name = "okd"
domain = "example.com"
# cluster url will be: okd.example.com
# cluster_name MUST match with AWS Secret names
```

Export terraform variables:
```
# hcloud credentials
export HCLOUD_TOKEN=<YOUR_HCLOUD_TOKEN>
export TF_VAR_HCLOUD_TOKEN=<YOUR_HCLOUD_TOKEN>

# AWS credentials
export TF_VAR_AWS_ACCESS_KEY_ID=RKXXXXXXXXXXXXXXX
export TF_VAR_AWS_SECRET_ACCESS_KEY=LXXXXXXXXXXXXXXXXXX
export TF_VAR_AWS_DEFAULT_REGION=eu-central-1

export AWS_ACCESS_KEY_ID=RKXXXXXXXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=LXXXXXXXXXXXXXXXXXX
export AWS_DEFAULT_REGION=eu-central-1
```

### Create Fedora CoreOS image

Build a Fedora CoreOS hcloud image with Packer and embed the hcloud user data source (`http://169.254.169.254/hetzner/v1/userdata`).  
This is required only once, for the first bootstrap.  

```
make hcloud_image
```

### Create cluster manifests and ignition configs

```
make generate_configs
```

### Build infrastructure with Terraform

```
make infrastructure BOOTSTRAP=true
```

### Wait for the bootstrap to complete

```
make wait_bootstrap
```

### Cleanup bootstrap and ignition node

```
make infrastructure
```

### Sign Worker CSRs

CSRs of the master nodes get signed by the bootstrap node automaticaly during the cluster bootstrap. CSRs from worker nodes must be signed manually.

```
make sign_csr; sleep 60; make sign_csr
```

This step is not necessary if you set `replicas_worker` to zero.

### Finish the installation process

```
make wait_completion
```

### Configure the cluster

```
make postinstall
```

### Update ephemeral token secrets

```
make get_ephemeral_token
```


### Run the pipeline

Check `workflows/aws-ecr-crontab.yml`


### Known issues

Can't pull some images: `pinging container registry registry.k8s.io: invalid status code from registry 403 (Forbidden)`   
Check:  
https://github.com/kubernetes/registry.k8s.io/issues/138  
https://github.com/kubernetes/registry.k8s.io/issues/138#issuecomment-1410233548  

Re-create the server in this case.  


### Re-create the server

Run these steps from the tollbox container:  

```
oc adm cordon worker01.os-dev-hz.example.com
oc adm drain worker01.os-dev-hz.example.com --ignore-daemonsets --delete-local-data
oc delete node worker01.os-dev-hz.example.com

cd terraform
terraform state list
terraform state list | grep worker01
terraform state list | grep worker | grep '[0]' ==> as it is "module.worker.module.hcloud_server_dns_a_records[0]"
terraform state rm 'module.worker.module.hcloud_server_dns_a_records[0].null_resource.create_record["worker01.os-dev-hz.example.com."]'
terraform state rm 'module.worker.hcloud_rdns.dns-ptr-ipv4[0]'
terraform state rm 'module.worker.hcloud_rdns.dns-ptr-ipv6[0]'
terraform state rm 'module.worker.hcloud_server.server[0]'

manually delete node in Hetzner UI

cd -
make infrastructure ==> it will create a new instance, to add it to the OKD4 cluster:
oc get csr
make sign_csr
oc get no
```

## Deployment of OCP

It's also possible OCP (with RedHat CoreOS) instead of OKD. Just export `DEPLOYMENT_TYPE=ocp`. For example:

```
export DEPLOYMENT_TYPE=ocp
export OPENSHIFT_RELEASE=4.6.35
make fetch build run
```

You can also select the latest version from a specific channel via:

```
export OCP_RELEASE_CHANNEL=stable-4.11
export OPENSHIFT_RELEASE=$(make latest_version)
make fetch build run
```

To setup OCP a pull secret in your install-config.yaml is necessary, which could be obtained from [cloud.redhat.com](https://cloud.redhat.com/).

## Firewall rules

~~As the Terraform module from Hetzer is currently unable to produce applied rules that contain hosts you deploy at the same time, you have to deploy them afterwards.~~

~~In order to do that, you should visit your Hetzner Web Console and apply the `okd-master` firewall rule to all hosts with the label `okd.io/master: true`, the `okd-base` to the label `okd.io/node: true` and `okd-ingress` to all nodes with the `okd.io/ingress: true` label. Since terraform will ignore firewall changes, this should not interfere with your existing state.~~

~~Note: This will keep hosts pingable, but isolate them complete from the internet, making the cluster only reachable through the load balancer. If you require direct SSH access, you can add another rule, that you apply nodes that allows access to port 22.~~

The firewall rules will be applied automatically.

## Based on

- [slauger](https://github.com/slauger/hcloud-okd4)

