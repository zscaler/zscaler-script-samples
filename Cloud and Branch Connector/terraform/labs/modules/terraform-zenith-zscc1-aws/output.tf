output "private_ip" {
  value = aws_instance.cc-vm.*.private_ip
}

output availability_zone {
  value = aws_instance.cc-vm.*.availability_zone
}

output "eni" {
  value = aws_network_interface.cc-vm-service-nic.*.id
}

output "id" {
  value = aws_instance.cc-vm.*.id
}

output "service_private_ip" {
  value = data.aws_network_interface.cc-vm-service-eni.*.private_ip
}