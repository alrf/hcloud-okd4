resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# private_key is required for ansible
resource "local_sensitive_file" "ssh" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = var.ssh_key
  file_permission = "0600"
}

resource "local_sensitive_file" "ssh_pub" {
  content         = tls_private_key.ssh.public_key_openssh
  filename        = "${var.ssh_key}.pub"
  file_permission = "0644"
}

resource "hcloud_ssh_key" "default" {
  name       = var.cluster_name
  public_key = tls_private_key.ssh.public_key_openssh
}

data "local_file" "kubeconfig" {
  count    = fileexists(var.kubeconfig) ? 1 : 0
  filename = var.kubeconfig
}

data "local_file" "kubeadmin" {
  count    = fileexists(var.kubeadmin_password) ? 1 : 0
  filename = var.kubeadmin_password
}

data "aws_secretsmanager_secret" "okd4_cluster" {
  name = "${var.cluster_name}/cluster"
}

resource "aws_secretsmanager_secret_version" "okd4_cluster" {
  count     = fileexists(var.kubeconfig) ? 1 : 0
  secret_id = data.aws_secretsmanager_secret.okd4_cluster.id
  secret_string = jsonencode({
    kubeconfig      = base64encode(data.local_file.kubeconfig[0].content)
    kubeadmin       = base64encode(data.local_file.kubeadmin[0].content)
    ssh_public_key  = tls_private_key.ssh.public_key_openssh
    ssh_private_key = tls_private_key.ssh.private_key_pem
  })
  # to save the original data only once, during the cluster bootstrapping
  lifecycle {
    ignore_changes = [secret_string, ]
  }
}

data "aws_secretsmanager_secret" "redhat_pullsecret" {
  name = "okd4/pullsecret"
}

data "aws_secretsmanager_secret_version" "redhat_pullsecret" {
  secret_id = data.aws_secretsmanager_secret.redhat_pullsecret.id
}

data "template_file" "install_config_yaml" {
  template = <<-EOF
---
apiVersion: v1
baseDomain: '${var.domain}'
metadata:
  name: '${var.cluster_name}'
compute:
- hyperthreading: Enabled
  name: worker
  replicas: ${var.replicas_worker}
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: ${var.replicas_master}
networking:
  clusterNetworks:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
  machineCIDR:
platform:
  none: {}
pullSecret: ${jsonencode(data.aws_secretsmanager_secret_version.redhat_pullsecret.secret_string)}
sshKey: "${trimspace(hcloud_ssh_key.default.public_key)}"
EOF
}

resource "local_file" "install_config_yaml" {
  content              = data.template_file.install_config_yaml.rendered
  filename             = "${path.root}/../install-config.yaml"
  directory_permission = "0755"
  file_permission      = "0644"
}


# get Github OAuth secrets
data "aws_secretsmanager_secret" "okd4_github" {
  name = "${var.cluster_name}/github"
}

data "aws_secretsmanager_secret_version" "okd4_github" {
  secret_id = data.aws_secretsmanager_secret.okd4_github.id
}

# custom console
data "template_file" "custom_console" {
  template = <<-EOF
---
apiVersion: config.openshift.io/v1
kind: Ingress
metadata:
  name: cluster
spec:
  componentRoutes:
    - name: console
      namespace: openshift-console
      hostname: console.${var.cluster_name}.${var.domain}
      servingCertKeyPairSecret:
        name: custom-certificate
EOF
}

resource "local_file" "custom_console" {
  count           = var.postinstall == true ? 1 : 0
  content         = data.template_file.custom_console.rendered
  filename        = "/tmp/custom-console.yaml"
  file_permission = "0644"
}


# github oauth
data "template_file" "github_oauth" {
  template = <<-EOF
---
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: 'GitHub.com YOUR Organization'
    mappingMethod: claim
    type: GitHub
    github:
      clientID: ${jsondecode(nonsensitive(data.aws_secretsmanager_secret_version.okd4_github.secret_string))["oauth_client"]}
      clientSecret:
        name: github-secret
      organizations:
      - YOURORG
EOF
}

resource "local_file" "github_oauth" {
  count           = var.postinstall == true ? 1 : 0
  content         = data.template_file.github_oauth.rendered
  filename        = "/tmp/github-oauth.yaml"
  file_permission = "0644"
}


# Hetzner PVC
data "template_file" "hetzner_pvc" {
  template = <<-EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: hcloud
  namespace: kube-system
stringData:
  token: ${var.hcloud_token}
EOF
}

resource "local_file" "hetzner_pvc" {
  count           = var.postinstall == true ? 1 : 0
  content         = data.template_file.hetzner_pvc.rendered
  filename        = "/tmp/hetzner-pvc.yaml"
  file_permission = "0644"
}


### Postinstall
resource "null_resource" "postinstall" {
  count = var.postinstall == true ? 1 : 0
  # always update resource
  triggers = {
    build_number = timestamp()
  }

  provisioner "local-exec" {
    command     = <<EOF
export KUBECONFIG=${var.kubeconfig};
export CERTDIR=/workspace/acme/*.${var.cluster_name}.${var.domain}_ecc;

# configuring RBAC
oc apply -f /workspace/terraform/modules/installer/templates/rbac

# expose registry, enable default URL
oc get clusteroperator image-registry
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed"}}'
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"emptyDir":{}}}}'
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
oc patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"managementState":"Managed"}}'
sleep 10
oc patch route/default-route --patch '{"spec":{"host":"registry.${var.cluster_name}.${var.domain}"}}' -n openshift-image-registry
sleep 10
oc get clusteroperator image-registry

# install certificate by default
oc create secret tls router-certs-default --cert=$${CERTDIR}/fullchain.cer --key=$${CERTDIR}/*.${var.cluster_name}.${var.domain}.key -n openshift-ingress --dry-run=client --output yaml | oc replace -f -
oc patch deployment/router-default --namespace openshift-ingress --patch "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"last-restart\":\"`date +'%s'`\"}}}}}"

# console route
oc create secret tls custom-certificate --cert=$${CERTDIR}/fullchain.cer --key=$${CERTDIR}/*.${var.cluster_name}.${var.domain}.key -n openshift-config --output yaml | oc replace -f -
oc apply -f /tmp/custom-console.yaml
sleep 10
oc get clusteroperator console

# configure GitHub auth
oc create secret generic github-secret --from-literal=clientSecret=${jsondecode(nonsensitive(data.aws_secretsmanager_secret_version.okd4_github.secret_string))["oauth_secret"]} -n openshift-config
oc apply -f /tmp/github-oauth.yaml
sleep 20
oc get clusteroperator authentication

# servicceaccount for Ephemeral env => this should go after "RBAC" step
oc create serviceaccount ephemeral-sa -n default && \
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:default:ephemeral-sa && \
oc adm policy add-cluster-role-to-user self-provisioner system:serviceaccount:default:ephemeral-sa && \
oc adm policy add-cluster-role-to-user self-provisioner ephemeral-sa

# pvc
oc apply -f /tmp/hetzner-pvc.yaml
# https://raw.githubusercontent.com/hetznercloud/csi-driver/v2.3.2/deploy/kubernetes/hcloud-csi.yml
# It works with "--feature-gates=Topology=false" and "hostNetwork: true" in DaemonSet
# https://github.com/hetznercloud/csi-driver/issues/92
oc apply -f /workspace/terraform/modules/installer/templates/hcloud-csi.yaml

# install cert for API, it takes ~10min to update
# DEGRADED OPERATOR!!! with "Unable to connect to the server: x509: certificate signed by unknown authority"
# oc patch apiserver cluster --type=merge -p '{"spec":{"servingCerts": {"namedCertificates": [{"names": ["api.${var.cluster_name}.${var.domain}"], "servingCertificate": {"name": "custom-certificate"}}]}}}'

    EOF
    interpreter = ["/usr/bin/env", "bash", "-c"]
  }
  depends_on = [
    local_file.custom_console
  ]
}
