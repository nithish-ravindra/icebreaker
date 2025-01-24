locals {
  default_tags = {
    environment = var.env
    version     = var.release_version
  }
}