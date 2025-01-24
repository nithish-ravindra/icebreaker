data "aws_vpc" "selected" {
  filter {
    name   = "tag:om"
    values = ["zync"]
  }
}