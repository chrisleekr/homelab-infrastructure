output "gitlab_initial_root_password" {
  value     = random_password.initial_root_password.result
  sensitive = true
}

output "gitlab_shell_host_keys" {
  value     = data.external.generate_keys.result
  sensitive = true
}
