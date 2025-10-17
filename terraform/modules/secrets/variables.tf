variable "name_prefix" {
  type = string
}

variable "secrets" {
  type      = map(string)
  sensitive = true
}
