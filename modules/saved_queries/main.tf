resource "terraform_data" "saved_query" {
  for_each         = var.saved_queries
  triggers_replace = sha256(jsonencode(each.value))
  input            = { project = var.project_id, id = each.key }

  provisioner "local-exec" {
    command     = <<-EOT
      curl -sSf -X POST \
        -H "Authorization: Bearer $(gcloud auth print-access-token)" \
        -H "X-Goog-User-Project: $PROJECT" \
        -H "Content-Type: application/json" \
        "https://cloudasset.googleapis.com/v1/projects/$PROJECT/savedQueries?savedQueryId=$QUERY_ID" \
        -d "$BODY"
    EOT
    environment = {
      PROJECT  = var.project_id
      QUERY_ID = each.key
      BODY     = jsonencode({ description = each.value.description, content = { iamPolicyAnalysisQuery = each.value.query } })
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      curl -sS -X DELETE \
        -H "Authorization: Bearer $(gcloud auth print-access-token)" \
        -H "X-Goog-User-Project: $PROJECT" \
        "https://cloudasset.googleapis.com/v1/projects/$PROJECT/savedQueries/$QUERY_ID"
    EOT
    environment = {
      PROJECT  = self.input.project
      QUERY_ID = self.input.id
    }
  }
}