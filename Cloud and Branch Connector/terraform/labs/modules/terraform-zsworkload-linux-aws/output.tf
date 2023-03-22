output "private_ip" {
  value = aws_instance.workload.*.private_ip
}
output "instance_id" {
  value = aws_instance.workload.*.id
}