provider "aws" {
  region = "us-east-1"  # Cambia esto a tu región preferida
}

resource "aws_instance" "web" {
  ami           = "ami-01b799c439fd5516a"  # AMI de Amazon Linux 2
  instance_type = "t2.micro"
  key_name      = "vockey"  # Cambia esto al nombre de tu par de claves SSH

  tags = {
    Name = "WebServer"
  }

  # Define el Security Group para permitir tráfico HTTP y SSH
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  provisioner "file" {
    source      = "install_apache.sh"
    destination = "/tmp/install_apache.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install_apache.sh",
      "sudo /tmp/install_apache.sh"
    ]
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("ssh.pem")  # Ruta a tu clave privada
    host        = self.public_ip
  }
}

#### VPC

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
variable "environment" {
  description = "The environment to deploy to"
  type        = string
  default     = "dev"
}
resource "aws_subnet" "subnet" {
  count = var.environment == "prod" ? 2 : 1
  vpc_id = aws_vpc.main.id
  cidr_block = var.environment == "prod" ? element(["10.0.1.0/24", "10.0.2.0/24"], count.index) : "10.0.1.0/24"
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
}
data "aws_availability_zones" "available" {
  state = "available"
}
resource "aws_security_group" "allow_tls" {
  name_prefix = "allow_tls_"
  vpc_id = aws_vpc.main.id
 
  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
 
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  ami           = "ami-01b799c439fd5516a" # Amazon Linux 2 AMI
  instance_type = var.environment == "prod" ? "t2.medium" : "t2.micro"
  subnet_id     = element(aws_subnet.subnet[*].id, 0)
  vpc_security_group_ids = [aws_security_group.allow_tls.id]
 
  tags = {
    Name = "MyAppInstance"
  }
}
