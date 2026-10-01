org_id       = "123456789012"
project_id   = "my-security-tooling-prod"
alert_emails = ["platform-oncall@example.com"]

feeds = {
  org-iam-changes = {
    scope_type   = "organization"
    scope_id     = "123456789012"
    content_type = "IAM_POLICY"
  }
  org-resource-changes = {
    scope_type   = "organization"
    scope_id     = "123456789012"
    content_type = "RESOURCE"
    asset_types = [
      "compute.googleapis.com/Firewall",
      "compute.googleapis.com/Network",
      "storage.googleapis.com/Bucket",
      "container.googleapis.com/Cluster",
      "sqladmin.googleapis.com/Instance",
    ]
  }
  org-orgpolicy-changes = {
    scope_type   = "organization"
    scope_id     = "123456789012"
    content_type = "ORG_POLICY"
  }
}

saved_queries = {
  who-has-owner = {
    description = "All identities with roles/owner across the org"
    query = {
      scope          = "organizations/123456789012"
      accessSelector = { roles = ["roles/owner"] }
    }
  }
}
