output "orgs" {
  value = data.tfe_organizations.orgs.names
}

output "latest_patch_version" {
  value = local.latest_patch_version
}

output "latest_minor_version" {
  value = local.latest_minor_version
}

output "latest_version" {
  value = var.check_patch_versions ? local.latest_patch_version : local.latest_minor_version
}

output "workspaces_and_versions" {
  value = var.check_patch_versions ? local.workspaces_and_patch_versions : local.workspaces_and_minor_versions
}

output "workspaces_with_old_versions" {
  value = var.check_patch_versions ? local.workspaces_with_old_patch_versions : local.workspaces_with_old_minor_versions
}

output "num_workspaces_with_old_versions" {
  value = var.check_patch_versions ? local.num_workspaces_with_old_patch_versions : local.num_workspaces_with_old_minor_versions
}
