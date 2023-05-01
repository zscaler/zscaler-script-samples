
locals {

usermapping = <<UM
<user-mapping>
<authorize 
username="cloudconnector"
password="8b4feec7f41e1c157701fc950372a8a2"
encoding="md5">
<connection name="Connect to Region1 Linux Workload (RDP)">
  <protocol>rdp</protocol>
  <param name="hostname">${module.workload.private_ip[0]}</param>
  <param name="port">3389</param>
  <param name="username">cloudconnector</param>
  <param name="password">CloudConnector2022!</param>
</connection>
</authorize>
</user-mapping>
UM
bastionconfig = <<BC
${module.bastion.public_ip}/32
BC
bastionconfig-dns = <<BCDNS
${module.bastion.public_dns}
BCDNS
}
output "usermapping" {
  value = local.usermapping
  sensitive = true
}
output "bastionconfig" {
  value = local.bastionconfig
}
output "bastionconfig-dns" {
  value = local.bastionconfig-dns
}
resource "local_file" "usermapping" {
  content = local.usermapping
  filename = "user-mapping.xml"
}
resource "local_file" "bastionconfig" {
  content = local.bastionconfig
  filename = "bastion-info.txt"
}
resource "local_file" "bastionconfig-dns" {
  content = local.bastionconfig-dns
  filename = "bastion-info-dns.txt"
}
output "wkld1_rdp" {
    value = "http://${module.bastion.public_dns}:8080/guacamole/#/client/Q29ubmVjdCB0byBSZWdpb24xIFdpbmRvd3MgV29ya2xvYWQgKFJEUCkAYwBkZWZhdWx0?username=cloudconnector&password=CloudConnector2022!"
}