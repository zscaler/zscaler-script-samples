#!/bin/zsh
 
  #globally used variables
  bold="\e[1m"
  red="\e[31m"
  cyan="\e[36m"
  endcolor="\e[0m"
  log_folder="/var/run/janus"
    
  #---------------------BC OS Section------------------------
  echo
  echo -e "${bold}${cyan}This is the BC OS Section${endcolor}"
  
  #display current time
  current_time=$(date)
  echo -e "${bold}The current time is: $current_time${endcolor}"
  echo

   system_model_info=$(cat /etc/cloud/cloud.cfg.d/userdata.cfg| grep "model")
   system_model=$(echo "$system_model_info" | awk -F'"' '{print $4}')
   echo -e "${bold}The device model is: $system_model${endcolor}"
   echo

   deploy_mode_info=$(cat /etc/cloud/cloud.cfg.d/userdata.cfg| grep "deployAsGateway")
   deploy_mode=$(echo "$deploy_mode_info" | awk -F' ' '{print $2}' | cut -d ',' -f 1)
   if [ "$deploy_mode" = "true" ]; then
    echo -e "${bold}The device is being deployed in Gateway mode${endcolor}"
   else
    echo -e "${bold}The device is being deployed in Single Arm mode${endcolor}"
   fi
   echo

    wan_status=0
	wan_info=$(cat /etc/cloud/cloud.cfg.d/userdata.cfg| grep -A 3 "\"interface_type\": \"WAN\"")
    wan_int_info=$(echo "$wan_info" | grep "name" | grep -v ".0")
    wan_int_count=$(echo "$wan_info" | grep -v ".0" | grep -c "name")
    wan_int=$(echo "$wan_int_info" | awk -F' ' '{print $2}' | cut -c 2-4)
    wan_int1=$(echo "$wan_int" | awk 'NR==1')
    wan_int2=$(echo "$wan_int" | awk 'NR==2')
    if [[ -n "$wan_int1" ]]; then
     echo -e "${bold}The First WAN interface is: $wan_int1 ${endcolor}"
	 wan_int1_status=$(ifconfig "$wan_int1" | grep UP 2>&1)
     if [ $? -eq 0 ]; then
      echo -e "${bold}The First WAN interface: $wan_int1 status is: UP${endcolor}"
	  wan_int1_info=$(ifconfig "$wan_int1" | grep inet | grep -v "0.0.0.0" 2>&1)
	  if [[ -n "wan_int1_info" ]]; then
	   wan_status=1
       wan_int1_ip=$(echo "$wan_int1_info" | awk -F' ' '{print $2}')
       wan_int1_mask=$(echo "$wan_int1_info" | awk -F' ' '{print $4}')
       echo -e "${bold}The First WAN interface IP is: $wan_int1_ip${endcolor}"
       echo -e "${bold}The First WAN interface Subnet Mask is: $wan_int1_mask${endcolor}"
       echo
	  else
	  echo -e "${red}The First WAN does not seem to be properly connected since no IP information was found. Please validate the interface is connected and the int can receive DHCP ${endcolor}"
	  echo
	  fi
     else
      echo -e "${bold}WAN interface: $wan_int1 status is: DOWN${endcolor}"
     fi
      if [[ -n "$wan_int2" ]]; then
       echo -e "${bold}The Second WAN interface is: $wan_int2 ${endcolor}"
	   wan_int2_status=$(ifconfig "$wan_int2" | grep UP 2>&1)
       if [ $? -eq 0 ]; then
        echo -e "${bold}The Second WAN interface: $wan_int2 status is: UP${endcolor}"
		wan_int2_info=$(ifconfig "$wan_int2" | grep inet | grep -v "0.0.0.0" 2>&1)
	    if [[ -n "wan_int2_info" ]]; then
		 wan_status=1
         wan_int2_ip=$(echo "$wan_int2_info" | awk -F' ' '{print $2}')
         wan_int2_mask=$(echo "$wan_int2_info" | awk -F' ' '{print $4}')
         echo -e "${bold}The Second WAN interface IP is: $wan_int2_ip${endcolor}"
         echo -e "${bold}The Second WAN interface Subnet Mask is: $wan_int2_mask${endcolor}"
         echo
	    else
		 echo -e "${red}The Second WAN does not seem to be properly connected since no IP information was found. Please validate the interface is connected and the int can receive DHCP ${endcolor}"
		 echo
		fi
       else
        echo -e "${bold}the Second WAN interface: $wan_int2 status is: DOWN${endcolor}"
       fi
      else
       echo -e "${bold}No Second WAN interface was configured${endcolor}"
	   echo
      fi
    else
     echo -e "${red}No configured WAN interface was found${endcolor}"
	 exit 0
    fi

  #if no active WAN interfaces where found exit script
  if [ "$wan_status" -eq 0 ]; then
	echo -e "${red}There seems to be no active WAN link${endcolor}"
	echo -e "${red}Stopping Script${endcolor}"
	exit 0
  fi
  
#  #what is the public IP for the primary connection
#  public_ip_primary=$(curl -s https://api.ipify.org)
#  if [ $? -eq 0 ]; then
#    echo -e "${bold}BC Public IP Address: $public_ip_primary${endcolor}"
#  else
#    echo -e"${red}Failed to fetch public IP address${endcolor}"
#  fi
#  echo
  
  #verify BC DNS servers
  bc_dns_server=$(cat /etc/resolv.conf 2>&1)
  if [ $? -eq 0 ]; then
   echo -e "${bold}These are the Branch Connector DNS Servers:${endcolor}"
   printf "%s" "$bc_dns_server"
  else
   echo -e "${red}Somerthing went wrong, cannot find the BC DNS servers${endcolor}"
  fi
  echo
  echo
  
  #Verify BC can resolve
  bc_resolve_test=$(drill google.com @8.8.8.8 2>&1)
  if [ $? -eq 0 ]; then
   echo -e "${bold}The Branch Connector seems to be able to resolve DNS:${endcolor}"
   printf "%s" "$bc_resolve_test"
  else
   echo -e "${red}something went wrong, The BC Cannot resolve${endcolor}"
  fi
  echo
  echo
  
###---------------------Edgeconnector Section------------------------  
echo -e "${bold}${cyan}This is the EdgeConnector Section${endcolor}"
  
  #which ZIA DC is the BC connected to
  zia_gateway=$(janus zia show_gateway)
  echo "${bold}These are the ZIA Connections{endcolor}"
  printf "%s" "$zia_gateway"
  echo
  echo
  
  #Validate if ZPA is enabled on the Edgeconnector
  zpa_enabled=$(janus zpa is_enabled)
  if [ "$zpa_enabled" = "true" ]; then
   zpa_broker_collect=$(janus zpa show_broker_info)
   zpa_broker_info=$(echo $zpa_broker_collect | grep "zpath.net" | head -1)
   zpa_broker_hostname=$(echo $zpa_broker_info | awk '{print $2}')
   zpa_broker_ip=$(echo $zpa_broker_info | awk '{print $6}')
   echo "${bold}ZPA is Connected to $zpa_broker_hostname with IP address $zpa_broker_ip${endcolor}"
  else
   echo "${red}ZPA seems to not be enabled for the BranchConnector${endcolor}"
  fi
  echo
  
  #last configuration updates
      ## Search in log files starting from the last modified file
      for configuration_log_file in $(ls -t "$log_folder"/*); do
              last_config_result=$(grep -r -e "New Incoming Policy Configuration" "$configuration_log_file" | tail -1)
              if [[ -n "$last_config_result" ]]; then
               last_config_date=$(echo "$last_config_result" | awk -F' ' '{print $1}' | cut -c 2-12)
               last_config_timestamp=$(echo "$last_config_result" | awk -F' ' '{print $2}' | cut -c 1-8)
                   echo -e "${bold}The Last Configuration change is: $last_config_date $last_config_timestamp${endcolor}"
                   echo -e "\t ---> $last_config_result"
                  break
              fi
      done
	  echo
   
  
  
###---------------------APPCONNECTOR Section------------------------
echo -e "${bold}${cyan}This is the AppConnector Section${endcolor}"
echo
  
  #verify AppC is enabled/enrolled
  appconnector_enabled=0
  appc_enabled_collect=$(cat /etc/cloud/cloud.cfg.d/userdata.cfg | grep "enable")
  appc_enabled=$(echo "$appc_enabled_collect" | awk -F' ' '{print $2}' | cut -c 2-4)
  if [ "$appc_enabled" = "yes" ]; then
   echo -e "${bold}App Connector is Enabled${endcolor}"
   appconnector_enabled=1
  else
   echo -e "${bold}App Connector is NOT enabled${endcolor}"
  fi
  
  if [ $appconnector_enabled -eq 1 ]; then
  
   #---------------------APPCONNECTOR Section (if provisioning is true)------------------------
   #verify AppC routing Table
   appc_routing_table=$(setfib 1 netstat -rn4 2>&1)
   if [ $? -eq 0 ]; then
    echo -e "${bold}The App Connector Routing Table:${endcolor}"
    printf "%s" "$appc_routing_table"
   else
    echo -e "${red}something went wrong, cannot find a routing table for the AppC${endcolor}"
   fi
   echo
   echo   
    
   #verify AppC can ping internet
   appc_ping_test=$(setfib 1 ping -c 3 104.18.29.74 2>&1)
   if [ $? -eq 0 ]; then
    echo -e "${bold}The App Connector seems to be able to reach the internet.. ping Zscaler.com:${endcolor}"
    printf "%s" "$appc_ping_test"
   else
    echo -e "${red}something went wrong, The AppC Cannot reach the internet${endcolor}"
    echo -e "${red}This could be fine, if ICMP is blocked, it is not mandatory to be allowed for the AppC to work${endcolor}"
   fi
   echo
   echo
   
   #verify AppC DNS servers
   appc_dns_server=$(cat /etc/resolv.conf.fib1 2>&1)
   if [ $? -eq 0 ]; then
    echo -e "${bold}These are the App Connector DNS Servers:${endcolor}"
    printf "%s" "$appc_dns_server"
   else
    echo -e "${red}Somerthing went wrong, cannot find the AppC DNS servers${endcolor}"
   fi
   echo
   echo
   
   #Verify AppC can resolve
   appc_resolve_failed=0
   appc_resolve_test=$(setfib 1 drill google.com @8.8.8.8 2>&1)
    if [ $? -eq 0 ]; then
     echo -e "${bold}The App Connector seems to be able to resolve DNS:${endcolor}"
     printf "%s" "$appc_resolve_test"
    else
     echo -e "${red}something went wrong, The AppC Cannot resolve${endcolor}"
	 appc_resolve_failed=1
    fi
    echo
    echo
   
   #verify AppC can connect to enrollment hosts
    appc_connection_failed=0
    if [ $appc_resolve_failed -eq 1 ]; then
	 echo -e "${red}DNS failed, skipping connection checks for AppC${endcolor}"
	else
	 appc_urls=("any.co2slbr.prod.zpath.net" "any.co2br.prod.zpath.net" "yum.private.zscaler.com" "enrollment.private.zscaler.com" "zpa-updates.prod.zpath.net" "dist.private.zscaler.com")
     for appc_url in "${appc_urls[@]}"; do
      appc_output=$(setfib 1 nc -z "$appc_url" 443 2>&1)
       if [ $? -eq 0 ]; then
        echo -e "${bold}Connection to $appc_url on port 443 was successful.${endcolor}"
       else
        echo -e "${red}Connection to $appc_url on port 443 failed.${endcolor}"
	    appc_connection_failed=1
       fi
     done
	fi
    echo
	
	if [ $appc_connection_failed -eq 1 ]; then
	 echo -e  "${red} Please verify outbound policies whether the AppConnector is allowed to connect to all required destinations${endcolor}"
	else
	 echo -e  "${bold} All AppC outbound connection seems to work as expected${endcolor}"
	fi
	echo
	
   
    #fetch App Connector name
    connector_name_log=$(cat -n /var/log/messages | grep zpa-connector | grep Name= | tail -1)
    connector_name=$(echo "$connector_name_log" | awk -F':' '{print $6}' | cut -c 6-)
    echo -e "${bold}The App Connector on this BC is named: $connector_name${endcolor}"
    echo -e "\t ---> $connector_name_log"
    
    #fetch App Connector Control Connection 
    connector_control_log=$(cat -n /var/log/messages | grep "Broker control connection" | tail -1)
    connector_control=$(echo "$connector_control_log" | awk -F';' '{print $2}')
    echo -e "${bold}The App Connector Control connection on this BC is: $connector_control${endcolor}"
    echo -e "\t ---> $connector_control_log"
  else
   echo -e "${bold}The App Connector is not Enabled, Skipping AppConnector verifications${endcolor}"
  fi
  echo  
exit 0