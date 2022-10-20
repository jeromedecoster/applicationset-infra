resource "local_file" "template_file" {
  for_each = fileset("${local.project_dir}/argocd/.tmpl/", "**")
  content  = templatefile("${local.project_dir}/argocd/.tmpl/${each.value}", local.template_vars)
  filename = pathexpand("${local.project_dir}/argocd/${each.value}")
}
