
provider "aws" {

  region = var.aws_region

}
 
resource "aws_vpc" "tf" {

  cidr_block = var.vpc_cidr_block

}
 
resource "aws_subnet" "selected" {

  vpc_id                  = aws_vpc.tf.id

  cidr_block              = var.subnet_cidr_block

  map_public_ip_on_launch = true

}
 
resource "aws_internet_gateway" "selected" {

  vpc_id = aws_vpc.tf.id

}
 
resource "aws_route_table" "selected" {

  vpc_id = aws_vpc.tf.id
 
  route {

    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.selected.id

  }

}
 
resource "aws_route_table_association" "selected" {

  subnet_id      = aws_subnet.selected.id

  route_table_id = aws_route_table.selected.id

}
 
resource "aws_security_group" "instance" {

  name   = "terraform-example-instance"

  vpc_id = aws_vpc.tf.id
 
  ingress {

    from_port   = 80

    to_port     = 80

    protocol    = "tcp"

    cidr_blocks = ["0.0.0.0/0"]

  }
 
  ingress {

    from_port   = 22

    to_port     = 22

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
 
resource "aws_sns_topic" "example" {

  name = "example-topic"

}
 
resource "aws_sns_topic_subscription" "example" {

  topic_arn = aws_sns_topic.example.arn

  protocol  = "email"

  endpoint  = var.subscription_email

}
 
resource "aws_instance" "example" {

  subnet_id              = aws_subnet.selected.id

  ami                    = var.ami

  instance_type          = var.instance_type

  key_name               = var.key_name

  vpc_security_group_ids = [aws_security_group.instance.id]

  tags = {

    Name = "example-instance"

  }
 
  iam_instance_profile = "LabInstanceProfile"
 
  user_data = <<-EOF

    #!/bin/bash

    sudo yum update -y && sudo yum install httpd -y && sudo systemctl start httpd && sudo systemctl enable httpd

    sudo chkconfig httpd on

    cd /var/www/html

    sudo yum install php php-cli php-json php-mbstring -y

    sudo php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"

    sudo php composer-setup.php

    sudo php -r "unlink('composer-setup.php');"

    sudo php composer.phar require aws/aws-sdk-php

    echo "AddType application/x-httpd-php .php" | sudo tee -a /etc/httpd/conf/httpd.conf

    sudo systemctl restart httpd
 
    echo "<!DOCTYPE html>

    <html lang='en'>

    <head>

        <meta charset='UTF-8'>

        <meta name='viewport' content='width=device-width, initial-scale=1.0'>

        <title>Contact Form</title>

    </head>

    <body>

        <h1>Contact Form</h1>

        <form action='submit.php' method='POST'>

            <label for='name'>Name:</label><br>

            <input type='text' id='name' name='name' required><br>

            <label for='email'>Email:</label><br>

            <input type='email' id='email' name='email' required><br>

            <label for='message'>Message:</label><br>

            <textarea id='message' name='message' rows='4' required></textarea><br>

            <input type='submit' value='Submit'>

        </form>

    </body>

    </html>

    " | sudo tee index.html > /dev/null
 
    cat <<EOP > submit.php

    <?php

    require 'vendor/autoload.php';
 
    use Aws\Sns\SnsClient;

    use Aws\Exception\AwsException;
 
    if (\$_SERVER["REQUEST_METHOD"] == "POST") {

        \$name = \$_POST["name"];

        \$email = \$_POST["email"];

        \$message = \$_POST["message"];
 
        \$snsTopicArn = "${aws_sns_topic.example.arn}";
 
        \$snsClient = new SnsClient([

            'version' => 'latest',

            'region' => 'us-east-1'

        ]);
 
        \$messageToSend = json_encode([

            'email' => \$email,

            'name' => \$name,

            'message' => \$message

        ]);
 
        try {

            \$snsClient->publish([

                'TopicArn' => \$snsTopicArn,

                'Message' => \$messageToSend

            ]);
 
            echo "Message sent successfully.";

        } catch (AwsException \$e) {

            echo "Error sending message: " . \$e->getMessage();

        }

    } else {

        http_response_code(405);

        echo "Method Not Allowed";

    }

    ?>

    EOP

  EOF

}
 
# resource "aws_iam_role_policy_attachment" "sns_policy_attachment" {

#  role       = "LabRol"

#  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"

#}
 
output "public_ip" {

  value = aws_instance.example.public_ip

}
 
output "sns_topic_arn" {

  value = aws_sns_topic.example.arn

}
 