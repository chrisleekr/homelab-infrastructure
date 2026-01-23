plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Additional rules for improved code quality
# Reference: https://github.com/terraform-linters/tflint-ruleset-terraform

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}
