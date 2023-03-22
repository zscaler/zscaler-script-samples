locals {
usermapping = <<UM
<user-mapping>
<authorize 
username="cloudconnector"
password="8b4feec7f41e1c157701fc950372a8a2"
encoding="md5">
<connection name="Connect to Region1 Cloud Connector 1">
  <protocol>ssh</protocol>
  <param name="hostname">${module.cc-vm.private_ip[0]}</param>
  <param name="port">22</param>
  <param name="username">zsroot</param>
  <param name="private-key">${tls_private_key.key.private_key_pem}</param>
</connection>
<connection name="Connect to Region1 Linux Workload (RDP)">
  <protocol>rdp</protocol>
  <param name="hostname">${module.workload1.private_ip[0]}</param>
  <param name="port">3389</param>
  <param name="username">cloudconnector</param>
  <param name="password">CloudConnector2022!</param>
</connection>
<connection name="Connect to Region1 Linux Workload (SSH)">
  <protocol>ssh</protocol>
  <param name="hostname">${module.workload1.private_ip[0]}</param>
  <param name="port">22</param>
  <param name="username">cloudconnector</param>
  <param name="private-key">${tls_private_key.key.private_key_pem}</param>
</connection>
<connection name="Connect to Region2 Cloud Connector 1">
  <protocol>ssh</protocol>
  <param name="hostname">${module.cc-vm2.public_ip[0]}</param>
  <param name="port">22</param>
  <param name="username">zsroot</param>
  <param name="private-key">${tls_private_key.key1.private_key_pem}</param>
</connection>
<connection name="Connect to Region2 Linux Workload (RDP)">
  <protocol>rdp</protocol>
  <param name="hostname">${module.workload2.public_ip[0]}</param>
  <param name="port">3389</param>
  <param name="username">cloudconnector</param>
  <param name="password">CloudConnector2022!</param>
</connection>
<connection name="Connect to Region2 Linux Workload (SSH)">
  <protocol>ssh</protocol>
  <param name="hostname">${module.workload2.public_ip[0]}</param>
  <param name="port">22</param>
  <param name="username">cloudconnector</param>
  <param name="private-key">${tls_private_key.key1.private_key_pem}</param>
</connection>
</authorize>
</user-mapping>
UM
guacamole = <<GM
cc1 = ${module.bastion.public_dns}:8080/guacamole/#/client/Q29ubmVjdCB0byBVU0Vhc3QyIENsb3VkIENvbm5lY3RvcgBjAGRlZmF1bHQ?username=cloudconnector&password=CloudConnector2022!
cc2 = ${module.bastion.public_dns}:8080/guacamole/#/client/Q29ubmVjdCB0byBVU1dlc3QyIENsb3VkIENvbm5lY3RvcgBjAGRlZmF1bHQ?username=cloudconnector&password=CloudConnector2022!
wkld1-rdp = ${module.bastion.public_dns}:8080/guacamole/#/client/Q29ubmVjdCB0byBVU0Vhc3QyIFdvcmtsb2FkIChSRFApAGMAZGVmYXVsdA?username=cloudconnector&password=CloudConnector2022!
wkld1-ssh = ${module.bastion.public_dns}:8080/guacamole/#/client/Q29ubmVjdCB0byBVU0Vhc3QyIFdvcmtsb2FkIChTU0gpAGMAZGVmYXVsdA?username=cloudconnector&password=CloudConnector2022!
wkld2-rdp = ${module.bastion.public_dns}:8080/guacamole/#/client/Q29ubmVjdCB0byBVU1dlc3QyIFdvcmtsb2FkIChSRFApAGMAZGVmYXVsdA?username=cloudconnector&password=CloudConnector2022!
wkld2-ssh = ${module.bastion.public_dns}:8080/guacamole/#/client/Q29ubmVjdCB0byBVU1dlc3QyIFdvcmtsb2FkIChTU0gpAGMAZGVmYXVsdA?username=cloudconnector&password=CloudConnector2022!
zia-portal = admin.${cloudname}
cc-portal = connector.${cloudname}
GM
bastionconfig = <<BC
${module.bastion.public_ip}/32
BC
bastionconfig-dns = <<BCDNS
${module.bastion.public_dns}
BCDNS
workload1 = <<WORK1
${module.workload1.instance_id[0]}
WORK1
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
output "guacamole" {
  value = local.guacamole
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
resource "local_file" "guacamole" {
  content = local.guacamole
  filename = "guacamole.txt"
}