output "private_ip" {
  value = aws_instance.workload.*.private_ip
}
output "public_ip" {
  value = aws_instance.workload.*.public_ip
}
output "instance_id" {
  value = aws_instance.workload.*.id
}
# output "password" {
#   value = "${rsadecrypt(aws_instance.workload.*.password_data[0], var.pem_output)}"
# }