locals {
usermapping = <<UM
<user-mapping>
<authorize 
<!--DEMO CREDENTIALS-->
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
  <!--DEMO CREDENTIALS-->
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
<connection name="Connect to Region1 App Connector 1">
  <protocol>ssh</protocol>
  <param name="hostname">${module.ac-vm.private_ip[0]}</param>
  <param name="port">22</param>
  <param name="username">admin</param>
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
  <!--DEMO CREDENTIALS-->
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
output "cc1" {
   value = "http://${module.bastion.public_dns}:8080/guacamole/#/client/Q29ubmVjdCB0byBSZWdpb24xIENsb3VkIENvbm5lY3RvciAxAGMAZGVmYXVsdA?username=cloudconnector&password=CloudConnector2022!"
}
output "cc2" {
   value = "http://${module.bastion.public_dns}:8080/guacamole/#/client/Q29ubmVjdCB0byBSZWdpb24yIENsb3VkIENvbm5lY3RvciAxAGMAZGVmYXVsdA?username=cloudconnector&password=CloudConnector2022!"
}
output "wkld1_rdp" {
    value = "http://${module.bastion.public_dns}:8080/guacamole/#/client/Q29ubmVjdCB0byBSZWdpb24xIExpbnV4IFdvcmtsb2FkIChSRFApAGMAZGVmYXVsdA?username=cloudconnector&password=CloudConnector2022!"
}
output "wkld1_ssh" {
   value = "http://${module.bastion.public_dns}:8080/guacamole/#/client/Q29ubmVjdCB0byBSZWdpb24xIExpbnV4IFdvcmtsb2FkIChTU0gpAGMAZGVmYXVsdA?username=cloudconnector&password=CloudConnector2022!"
}
output "wkld2_rdp" {
   value = "http://${module.bastion.public_dns}:8080/guacamole/#/client/Q29ubmVjdCB0byBSZWdpb24yIExpbnV4IFdvcmtsb2FkIChSRFApAGMAZGVmYXVsdA?username=cloudconnector&password=CloudConnector2022!"
}
output "wkld2_ssh" {
   value = "http://${module.bastion.public_dns}:8080/guacamole/#/client/Q29ubmVjdCB0byBSZWdpb24yIExpbnV4IFdvcmtsb2FkIChTU0gpAGMAZGVmYXVsdA?username=cloudconnector&password=CloudConnector2022!"
}
output "ac1" {
   value = "http://${module.bastion.public_dns}:8080/guacamole/#/client/Q29ubmVjdCB0byBSZWdpb24xIEFwcCBDb25uZWN0b3IgMQBjAGRlZmF1bHQ?username=cloudconnector&password=CloudConnector2022!"
}
output "zia_portal" {
    value = "https://admin.${var.cloudname}"
}
output "zpa_portal" {
    value = "https://admin.private.zscaler.com"
}
output "cc_portal" {
    value = "https://connector.${var.cloudname}"
}
