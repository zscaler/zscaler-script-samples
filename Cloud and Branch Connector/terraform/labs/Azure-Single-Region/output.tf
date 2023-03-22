locals {
  user-mapping = <<UM
<user-mapping>
<authorize 
username="cloudconnector"
password="8b4feec7f41e1c157701fc950372a8a2"
encoding="md5">
<connection name="RDP to Windows Host">
  <protocol>rdp</protocol>
  <param name="hostname">${module.workload.private_ip[0]}</param>
  <param name="port">3389</param>
  <param name="username">${var.vm_username}</param>
  <param name="password">${var.vm_password}</param>
  <param name="ignore-cert">true</param>
  <param name="security">nla</param>
</connection>
<connection name="RDP to Linux Host">
  <protocol>rdp</protocol>
  <param name="hostname">${module.workload-lin.private_ip[0]}</param>
  <param name="port">3389</param>
  <param name="username">${var.vm_username}</param>
  <param name="password">${var.vm_password}</param>
  <param name="ignore-cert">true</param>
</connection>
<connection name="SSH to CC1">
  <protocol>ssh</protocol>
  <param name="hostname">${var.zones_enabled == true ? module.cc-vm[0].private_ip[0] : module.cc-vm-nozone[0].private_ip[0]}</param>
  <param name="port">22</param>
  <param name="username">zsroot</param>
  <param name="private-key">${tls_private_key.key.private_key_pem}</param>
</connection>
<connection name="SSH to CC2">
  <protocol>ssh</protocol>
  <param name="hostname">${var.zones_enabled == true ? module.cc-vm[0].private_ip[1] : module.cc-vm-nozone[0].private_ip[1]}</param>
  <param name="port">22</param>
  <param name="username">zsroot</param>
  <param name="private-key">${tls_private_key.key.private_key_pem}</param>
</connection>
</authorize>
</user-mapping>
UM
}
output "user-mapping" {
  value = local.user-mapping
  sensitive = true
}
output "bastion_ip" {
  value = module.bastion.public_ip
}
resource "local_file" "user-mapping" {
  content = local.user-mapping
  filename = "user-mapping.xml"
}