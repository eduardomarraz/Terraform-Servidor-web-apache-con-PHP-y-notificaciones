


# Mostrar información resultante de la infraestructura

output "public_ip" {
  description = "Dirección IP publica de la instancia EC2"
  value       = aws_instance.web.public_ip
}
