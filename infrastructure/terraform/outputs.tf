output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.opentube.id
}

output "public_ip" {
  description = "Elastic IP address"
  value       = aws_eip.opentube.public_ip
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/opentube-aws ubuntu@${aws_eip.opentube.public_ip}"
}

output "http_url" {
  description = "HTTP URL"
  value       = "http://${aws_eip.opentube.public_ip}"
}

output "instance_state" {
  description = "Instance state"
  value       = aws_instance.opentube.instance_state
}
