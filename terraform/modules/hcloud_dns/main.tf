resource "null_resource" "create_a_record" {
  triggers = {
    ## to always update resource
    #build_number  = timestamp()
    api_url   = local.api_url
    zone_id   = var.zone_id
    api_token = var.api_token
  }
  for_each = var.type == "A" ? var.records : {}

  # create record
  provisioner "local-exec" {
    command     = <<EOF
curl -s "${self.triggers.api_url}?zone_id=${self.triggers.zone_id}" -H "Auth-API-Token: ${self.triggers.api_token}" | jq -e --raw-output ".records[] | select(.name==\"${each.key}\") | .id" || \
curl -s -X "POST" "${self.triggers.api_url}" -H "Auth-API-Token: ${self.triggers.api_token}" -d $'{
  "value": "${each.value}",
  "ttl": 60,
  "type": "A",
  "name": "${each.key}",
  "zone_id": "${self.triggers.zone_id}"
}'
EOF
    interpreter = ["/usr/bin/env", "bash", "-c"]
  }

  #[[ ! -z "$var" ]] && echo "Not empty" || echo "Empty"
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
