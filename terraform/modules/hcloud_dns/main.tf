data "aws_secretsmanager_secret" "hetzner_dns" {
  name = "hetzner/dns"
}

data "aws_secretsmanager_secret_version" "hetzner_dns" {
  secret_id = data.aws_secretsmanager_secret.hetzner_dns.id
}

resource "null_resource" "create_record" {
  triggers = {
    ## to always update resource
    #build_number  = timestamp()
    build_number = var.force_update == "" ? 1 : var.force_update
    api_url      = jsondecode(data.aws_secretsmanager_secret_version.hetzner_dns.secret_string)["api_url"]
    zone_id      = jsondecode(data.aws_secretsmanager_secret_version.hetzner_dns.secret_string)["zone_id"]
    api_token    = jsondecode(data.aws_secretsmanager_secret_version.hetzner_dns.secret_string)["api_key"]
  }
  for_each = contains(["A", "CNAME"], var.type) ? var.records : {}

  # create record
  provisioner "local-exec" {
    command     = <<EOF
curl -s "${self.triggers.api_url}?zone_id=${self.triggers.zone_id}" -H "Auth-API-Token: ${self.triggers.api_token}" | jq -e --raw-output ".records[] | select(.name==\"${each.key}\") | .id" || \
curl -s -X "POST" "${self.triggers.api_url}" -H "Auth-API-Token: ${self.triggers.api_token}" -d $'{
  "value": "${each.value}",
  "ttl": 60,
  "type": "${var.type}",
  "name": "${each.key}",
  "zone_id": "${self.triggers.zone_id}"
}'
EOF
    interpreter = ["/usr/bin/env", "bash", "-c"]
  }

  # delete record on destroy
  provisioner "local-exec" {
    when        = destroy
    command     = <<EOF
RecordID=$(curl -s "${self.triggers.api_url}?zone_id=${self.triggers.zone_id}" -H "Auth-API-Token: ${self.triggers.api_token}" | jq -e --raw-output ".records[] | select(.name==\"${each.key}\") | .id")
echo "${each.key} => $RecordID"
[[ ! -z "$RecordID" ]] && curl -s -X "DELETE" "${self.triggers.api_url}/$RecordID" -H "Auth-API-Token: ${self.triggers.api_token}" && sleep 1
EOF
    interpreter = ["/usr/bin/env", "bash", "-c"]
  }

}
