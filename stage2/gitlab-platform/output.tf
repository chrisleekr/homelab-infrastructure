output "gitlab_initial_root_password" {
  description = "The initial root password for GitLab admin access"
  value       = random_password.initial_root_password.result
  sensitive   = true
}

output "gitlab_shell_host_keys" {
  description = "The SSH host keys for GitLab Shell, used for Git SSH operations"
  value       = data.external.generate_keys.result
  sensitive   = true
}
