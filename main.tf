terraform {
  // When testing new versions of this... uncomment the below

  /*
  cloud {
    organization = "lmhd"

    workspaces {
      name = "terraform-version-check"
    }
  }
*/

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

  # Use SemVer terminology, i.e. Major.Minor.Patch
  # (Marketting Terminology usually calls these ???.Major.Minor)
  latest_patch_version = local.latest_version

  latest_version_split = split(".", local.latest_version)
  latest_minor_version = join(".", [local.latest_version_split[0], local.latest_version_split[1]])
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

  # Patch Versions

  workspaces_and_patch_versions = {
    for k, workspace in data.tfe_workspace.workspace :
    k => workspace.terraform_version
  }

  workspaces_with_old_patch_versions = {
    for k, workspace_version in local.workspaces_and_patch_versions :
    k => workspace_version if
    workspace_version != local.latest_patch_version &&
    workspace_version != "latest"
  }

  num_workspaces_with_old_patch_versions = length(keys(local.workspaces_with_old_patch_versions))


  # Minor Versions

  workspaces_and_minor_versions = {
    for k, workspace in data.tfe_workspace.workspace :
    k => try(
      join(".",
        [
          split(".", workspace.terraform_version)[0],
          split(".", workspace.terraform_version)[1],
        ]
      ),
      workspace.terraform_version
    )
  }

  workspaces_with_old_minor_versions = {
    for k, workspace_version in local.workspaces_and_minor_versions :
    k => workspace_version if
    workspace_version != local.latest_minor_version &&
    workspace_version != "latest"
  }

  num_workspaces_with_old_minor_versions = length(keys(local.workspaces_with_old_minor_versions))


  # And whichever we're actually interested in
  workspaces_with_old_versions     = var.check_patch_versions ? local.workspaces_with_old_patch_versions : local.workspaces_with_old_minor_versions
  num_workspaces_with_old_versions = var.check_patch_versions ? local.num_workspaces_with_old_patch_versions : local.num_workspaces_with_old_minor_versions
}



#
# Assert that there are no workspaces using old versions
#

resource "terraform_data" "assert" {
  lifecycle {
    postcondition {
      condition     = (local.num_workspaces_with_old_versions) == 0
      error_message = "Detected workspaces with old Terraform:\n${jsonencode(local.workspaces_with_old_versions)}"
    }
  }
}

