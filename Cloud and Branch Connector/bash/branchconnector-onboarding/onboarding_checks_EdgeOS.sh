#!/bin/sh

  #globally used variables
  bold="\e[1m"
  red="\e[31m"
  cyan="\e[36m"
  endcolor="\e[0m"

 clear
 echo
 echo -e "${bold}${cyan}This script is written for the purpose of validating whether the Branch Connector is ready for Provisioning and whether is has completed provisioning successfully${endcolor}"
 sleep 5

#check whether in BC01 or ZscalerOS
check_ztpagent=$(service ztpagent status)
if [ $? -eq 0 ]; then
 echo -e "${bold}This is a Hardware based Branch Connector!${endcolor}"
 echo -e "${bold}Continuing executing Script!${endcolor}"
else
 echo -e "${red}This is NOT a Hardware based Branch Connector!${endcolor}"
 echo -e "${red}Exiting Script!${endcolor}"
 exit 0
 echo
fi

#----------Check Hardware BC or Software BC----------

 #check hardware model
  model400=NCA-1040A
  model600=NCA-1513E
  model800=NCA-1515A
  
  system_product_name=$(sudo dmidecode -s system-product-name)
  if [ "$system_product_name" = "$model400" ]; then
          echo -e "${bold}The device model is ZT400${endcolor}"
		  device_model=ZT400
  elif [ "$system_product_name" = "$model600" ]; then
          echo -e "${bold}The device model is ZT600${endcolor}"
		  device_model=ZT600
  elif [ "$system_product_name" = "$model800" ]; then
          echo -e "${bold}The device model is ZT800${endcolor}"
		  device_model=ZT800
  else
          echo Hardware model not recognized, likely a VM deployment
  		echo -e "${bold}recognized name is: $system_product_name${endcolor}"
  		exit 0
  fi
  
 #set interfaces for device model
  if [ "$device_model" = "ZT400" ]; then
        mgmt_if=ge1
  elif [ "$device_model" = "ZT600" ]; then
        mgmt_if=ge1
  elif [ "$device_model" = "ZT800" ]; then
        mgmt_if=ge3
  else
        echo -e "${red}the device mgmt/wan interface was not found${endcolor}"
  fi
  
#---------------------ZscalerOS Section-------------------
  
 #display current time
  current_time=$(date)
  echo -e "${bold}The current time is: $current_time${endcolor}"
  
 #display hardware Serial Number
  hw_serial_number=$(sudo dmidecode -s system-serial-number)
  echo -e "${bold}The Hardware Serial number is: $hw_serial_number${endcolor}"
  
 #display certificate Serial Number
  cert_serial_number=$(sudo tpmutil certificate --serial)
  echo -e "${bold}$cert_serial_number${endcolor}"
  echo
  
 #display ZscalerOS Version
  zscalerOS=$(sudo sw show)
  echo -e "${bold}The ZscalerOS version is:${endcolor}"
  printf "%s" "$zscalerOS"
  echo
  echo
  
 #display Monit health
  monit_status=$(sudo monit summary)
  echo -e "${bold}The Health of monit is:${endcolor}"
  printf "%s" "$monit_status"
  echo
  echo
  
 #validate mgmt-port 
  mgmt_int_info=$(ip address show dev $mgmt_if)

  #extract interface status
  mgmt_int_status=$(echo $mgmt_int_info | awk -F' ' '{print $9}')	
  #extract mgmt interface MAC
  mgmt_int_mac=$(echo $mgmt_int_info | awk -F' ' '{print $15}')
  #extract interface IP
  mgmt_int_ip=$(echo $mgmt_int_info | awk -F' ' '{print $19}')
  	
    echo -e "${bold}The mgmt interface: Interface/Status/MAC/IP: $mgmt_if, $mgmt_int_status, $mgmt_int_mac, $mgmt_int_ip${endcolor}"
    echo

  #Validate mgmt-int can resolve
  mgmt_dns_check=$(nslookup www.zscaler.com 2>&1)
   if [ $? -eq 0 ]; then
    echo -e "${bold}DNS resolution seems to work:${endcolor}"
    printf "%s" "$mgmt_dns_check"
   else
    echo -e "${red}DNS resolution seems to have issues:${endcolor}"
    printf "%s" "$mgmt_dns_check"
   fi
  echo
  echo
  
  #validate mgmt-int can ping public internet
  mgmt_ping_check=$(ping -c 3 104.18.29.74 2>&1)
   if [ $? -eq 0 ]; then
    mgmt_ping_check_simple=$(printf "%s" "$mgmt_ping_check | head -4")
    echo -e "${bold}mgmt interface can successfully ping 104.18.29.74, zscaler website:${endcolor}"
    printf "%s" "$mgmt_ping_check_simple"
   else
    mgmt_ping_check_simple=$(printf "%s" "$mgmt_ping_check | head -4")
    echo -e "${red}mgmt interface cannot ping zscaler.com. not needed for enrollment, but might indicate connection issue:${endcolor}"
    printf "%s" "$mgmt_ping_check_simple"
   fi
  echo
  echo
  
  #validate mgmt-int can reach Zscaler services
    mgmt_urls=("connector.zscaler.net" "ecservice.zscaler.net" "pac.zscaler.net" "gateway.zscaler.net" "any.co2slbr.prod.zpath.net" "any.co2br.prod.zpath.net" "yum.private.zscaler.com" "pkg-repo.zscaler.com" "api.private.zscaler.com")

    for mgmt_url in "${mgmt_urls[@]}"; do
     mgmt_output=$(nc -z "$mgmt_url" 443 2>&1)
      if [ $? -eq 0 ]; then
       echo -e "${bold}Connection to $mgmt_url on port 443 was successful.${endcolor}"
      else
       echo -e "${red}Connection to $mgmt_url on port 443 failed.${endcolor}"
      fi
    done
    echo

  #validate if BC ZTP-Agent can auth to provisioning
	provisioning_auth_send=$(cat -n /var/log/syslog | grep --text 'Sending Request:' | grep --text ztpserver/api/v1/authenticate | tail -1)
	if [[ -n $provisioning_auth_send ]]; then
	 echo -e "${bold}Auth was send:${endcolor}"
	 echo -e "\t --> $provisioning_auth_send"
	else 
	 echo -e "${red}No record that Authentication was send has bene found${endcolor}"
	fi
	echo
	
	provisioning_auth_success=$(cat -n /var/log/syslog | grep --text 'Authentication' | tail -1)
	if [[ -n $provisioning_auth_success ]]; then
	echo -e "${bold}Auth was successfull:${endcolor}"
	echo -e "\t --> $provisioning_auth_success"
	else 
	 echo -e "${red}No successfull Authentication was found${endcolor}"
	fi
	echo

  #is there a provisioning URL available
    provision_not_ready=0
	provisioning_get_fail=$(cat -n /var/log/syslog | grep --text 'GetProvisioningURL failed:' | tail -1)
	provisioning_get_url=$(cat -n /var/log/syslog | grep --text 'GetProvisioningInfo from URL:' | tail -1)
	if [ -n "$provisioning_get_url" ]; then
	 echo -e "${bold}The Branch connector is provisioning:${endcolor}"
	 echo -e "\t --> $provisioning_get_url"
	else
	 echo -e "${red}The Branch connector is not able to find a provision URL yet${endcolor}"
	 echo -e "\t --> $provisioning_get_fail"
	 provision_not_ready=1
	fi
 
  #validate Provisioning status
   provisioning_completed=$(cat -n /var/log/syslog | grep --text 'provData' | tail -1)
   	if [ $provision_not_ready -eq 1 ]; then
	 exit 0
	else 
     if [[ -n $provisioning_completed ]]; then
      echo -e "${bold}Provisioning was completed Successfully:${endcolor}"
      echo -e "\t --> $provisioning_completed"
	 else
	  echo -e "${red}Provisioning is not ready yet:${endcolor}"
     fi
    fi
   echo	
exit 0