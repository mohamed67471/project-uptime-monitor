resource "aws_secretsmanager_secret" "app_secrets" {
  for_each = nonsensitive(var.secrets)

  name        = "${var.name_prefix}/${each.key}"
  description = "Secret for ${each.key}"

  tags = {
    Name = "${var.name_prefix}/${each.key}"
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  for_each = nonsensitive(var.secrets)

  secret_id     = aws_secretsmanager_secret.app_secrets[each.key].id
  secret_string = each.value
}
