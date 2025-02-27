# Servidor Web Apache con PHP y Notificaciones AWS SNS

Este proyecto crea una instancia de EC2 en AWS que ejecuta un servidor web Apache con soporte para PHP y envía notificaciones mediante AWS SNS. La infraestructura se define utilizando Terraform.

## Estructura del Proyecto

- **main.tf**: Configuración principal de Terraform para la instancia EC2, VPC, subred, grupo de seguridad y SNS.
- **install_apache.sh**: Script de configuración para instalar Apache, PHP y configurar el servidor.

## Recursos Implementados

- **VPC**: Red virtual para el despliegue de la instancia.
- **Subred**: Subred pública dentro de la VPC.
- **Grupo de Seguridad**: Permite tráfico HTTP (puerto 80) y SSH (puerto 22).
- **Instancia EC2**: Servidor web con Apache y PHP.
- **AWS SNS**: Servicio de notificaciones para recibir mensajes desde el servidor web.

## Instrucciones de Uso

### Pre-requisitos

- Terraform instalado
- Credenciales de AWS configuradas

### Despliegue

1. **Clona el repositorio:**

    ```bash
    git clone https://github.com/tu-usuario/tu-repositorio.git
    cd tu-repositorio
    ```

2. **Inicializa Terraform:**

    ```bash
    terraform init
    ```

3. **Aplica la configuración de Terraform:**

    ```bash
    terraform apply
    ```

    Confirma la ejecución escribiendo `yes` cuando se te solicite.

4. **Accede a la instancia:**

    Una vez finalizada la ejecución, obtén la dirección IP pública de la instancia desde la salida de Terraform y accede a ella mediante un navegador web.

### Archivos Principales

#### main.tf

```hcl
provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "tf" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "selected" {
  vpc_id                  = aws_vpc.tf.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "my_subnet"
  }
}

resource "aws_security_group" "allow_http_ssh" {
  name        = "allow_http_ssh"
  description = "Allow HTTP and SSH traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami           = "ami-01b799c439fd5516a"
  instance_type = "t2.micro"
  key_name      = "vockey"

  security_groups = [aws_security_group.allow_http_ssh.name]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd php php-cli php-json php-mbstring
              service httpd start
              chkconfig httpd on
              cd /var/www/html
              curl -sS https://getcomposer.org/installer | php
              php composer.phar require aws/aws-sdk-php
              cat << 'EOT' > index.html
              <!DOCTYPE html>
              <html lang="en">
              <head>
                  <meta charset="UTF-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1.0">
                  <title>Contact Form</title>
              </head>
              <body>
                  <h1>Contact Form</h1>
                  <form action="submit.php" method="POST">
                      <label for="name">Name:</label><br>
                      <input type="text" id="name" name="name" required><br>
                      <label for="email">Email:</label><br>
                      <input type="email" id="email" name="email" required><br>
                      <label for="message">Message:</label><br>
                      <textarea id="message" name="message" rows="4" required></textarea><br>
                      <input type="submit" value="Submit">
                  </form>
              </body>
              </html>
              EOT
              cat << 'EOT' > submit.php
              <?php
              require 'vendor/autoload.php';
               
              use Aws\Sns\SnsClient;
              use Aws\Exception\AwsException;
               
              if ($_SERVER["REQUEST_METHOD"] == "POST") {
                  $name = $_POST["name"];
                  $email = $_POST["email"];
                  $message = $_POST["message"];
               
                  $snsTopicArn = 'arn:aws:sns:us-east-1:XXXXXXX:test';
               
                  $snsClient = new SnsClient([
                      'version' => 'latest',
                      'region' => 'us-east-1'
                  ]);
               
                  $messageToSend = json_encode([
                      'email' => $email,
                      'name' => $name,
                      'message' => $message
                  ]);
               
                  try {
                      $snsClient->publish([
                          'TopicArn' => $snsTopicArn,
                          'Message' => $messageToSend
                      ]);
               
                      echo "Message sent successfully.";
                  } catch (AwsException $e) {
                      echo "Error sending message: " . $e->getMessage();
                  }
              } else {
                  http_response_code(405);
                  echo "Method Not Allowed";
              }
              ?>
              EOT
              EOF

  tags = {
    Name = "Apache-PHP-WebServer"
  }
  
  vpc_security_group_ids = [aws_security_group.allow_http_ssh.id]

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
    private_key = file("ssh.pem")
    host        = self.public_ip
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("path/to/your/id_rsa.pub")
}

resource "aws_sns_topic" "sns_topic" {
  name = "test"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "email"
  endpoint  = "your-email@example.com"
}

output "instance_ip" {
  value = aws_instance.web.public_ip
}
