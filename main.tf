terraform {
  required_providers {
    tfe = {
      source = "hashicorp/tfe"
    }
  }

  # Because we're using "terraform_data"
  required_version = ">= 1.4.0"
}



#
# First, list all orgs we have access to
#

data "tfe_organizations" "orgs" {

  lifecycle {
    postcondition {
      condition     = length(self.names) == 1
      error_message = "This module is designed to work with access to only one Terraform Organization"
    }
  }
}
output "orgs" {
  value = data.tfe_organizations.orgs.names

}

locals {
  org_name = data.tfe_organizations.orgs.names[0]
}




#
# Get Latest TF Version
#

data "http" "checkpoint-terraform" {
  url = "https://checkpoint-api.hashicorp.com/v1/check/terraform"

  # Optional request headers
  request_headers = {
    Accept = "application/json"
  }
}

locals {
  latest_version = jsondecode(data.http.checkpoint-terraform.response_body).current_version
}



#
# List all Workspaces
#


data "tfe_workspace_ids" "all" {
  names        = ["*"]
  organization = local.org_name
}

data "tfe_workspace" "workspace" {
  for_each = data.tfe_workspace_ids.all.ids

  name         = each.key
  organization = local.org_name
}



#
# List all workspaces which do not use the latest TF Version
#


locals {
  workspaces_and_versions = {
    for k, v in data.tfe_workspace.workspace :
    k => v.terraform_version
  }

  # TODO: The current limitation here is that if a workspace is not using EXACTLY
  # the latest version then we flag it as non-compliant. In reality... I probably
  # only care that it's using the latest major version (e.g. v1.4.x)
  # (Minor version, in SemVer speak. Major in marketting speak)
  workspaces_with_old_versions = {
    for k, v in data.tfe_workspace.workspace :
    k => v.terraform_version if
    v.terraform_version != local.latest_version
  }

  num_workspaces_with_old_versions = length(keys(local.workspaces_with_old_versions))
}



#
# Assert that there are no workspaces using old versions
#

resource "terraform_data" "assert" {
  lifecycle {
    precondition {
      condition     = local.num_workspaces_with_old_versions == 0
      error_message = "Detected workspaces with old Terraform:\n${jsonencode(local.workspaces_with_old_versions)}"
    }
  }
}




