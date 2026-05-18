variable "environment" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

variable "target_env" {
  type    = string
  default = "localstack"
}
