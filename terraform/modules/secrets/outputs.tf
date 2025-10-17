output "secret_arns" {
  value = {
    for key, secret in aws_secretsmanager_secret.app_secrets :
    key => secret.arn
  }
  sensitive = true
}
