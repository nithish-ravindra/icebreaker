# data "aws_vpc" "selected" {
#   filter {
#     name   = "tag:om"
#     values = ["zync"]
#   }
# }

data "aws_vpc" "selected" {
  filter {
    name   = "tag:om"
    values = ["zync"]
  }
}

data "aws_subnet_ids" "selected" {
  vpc_id = data.aws_vpc.selected.id
}

resource "aws_instance" "example" {
  ami           = "ami-0c55b159cbfafe1f0" # Replace with your desired AMI ID
  instance_type = "t2.micro"
  subnet_id     = data.aws_subnet_ids.selected.ids[0]

  tags = {
    Name = "example-instance"
  }
}