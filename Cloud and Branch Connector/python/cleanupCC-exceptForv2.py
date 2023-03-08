#!/usr/bin/env python3

import time, requests, json, sys, urllib3, getpass

cloudName = input("Cloud Name (e.g. zscloud.net): ")
username = input("Username: ")
password = getpass.getpass("Password: ")
apiKey = input("APIKey: ")

# Ask for VPC ID:
vpcID = input("Enter a VPC/VNet ID (e.g. vpc-00d78920e5c2cda42) to restrict the action to a specific VPC/VNet, or leave blank and press <Enter> to continue: ")

# Ask for CC IDs
prompt = "Enter the Active CC IDs (e.g. zs-cc-vpc-00d78920e5c2cda42-us-west-2b-VM-vkSjs) you wish to retain - 1 per line.\nLeave blank and press <Enter> when complete: "
ccID = []
line = input(prompt)
while line:
    ccID.append(str(line))
    line = input(prompt)

# Confirm Intentions
if not vpcID:  # VPC ID is empty
    if not ccID: # CC ID is empty
        print("You did not enter any CC IDs or a VPC/VNet ID. This will \033[0;37;41mremove all CC VMs (nuclear option)\033[0m")
        while True:
            ccConfirm = input("\033[0;31;43m\U000026A0 Are you sure you want to remove all CC VMs? Please answer YES or NO (case sensitive)\U000026A0 :\033[0m")
            if ccConfirm == "YES":
                break
            elif ccConfirm == "NO":
                print("Aborted")
                sys.exit()
                break
            else:
                print("Incorrect input, please try again (Please answer YES or NO)!")
    else: # CC ID entered
        print("You entered the following CC IDs that will be RETAINED:")
        print(ccID)
        while True:
            ccConfirm = input("\033[0;31;43m\U000026A0 Are you sure you want to remove all other CC VMs? Please answer YES or NO (case sensitive)\U000026A0 :\033[0m ")
            if ccConfirm == "YES":
                break
            elif ccConfirm == "NO":
                print("Aborted")
                sys.exit()
                break
            else:
                print("Incorrect input, please try again (Please answer YES or NO)!")

else: # VPC ID entered 
    if not ccID: # CC ID is empty
        print("You did not enter any CC IDs. This will remove all CC VMs within the following VPC/VNet: ")
        print(vpcID)
        while True:
            ccConfirm = input("\033[0;31;43m\U000026A0 Are you sure you want to remove all CC VMs within this VPC/VNet? Please answer YES or NO (case sensitive)\U000026A0 :\033[0m ")
            if ccConfirm == "YES":
                break
            elif ccConfirm == "NO":
                print("Aborted")
                sys.exit()
                break
            else:
                print("Incorrect input, please try again (Please answer YES or NO)!")
    else: # CC ID entered
        print(f"The following CC VMs will be RETAINED: {ccID} inside the follow VPC: {vpcID}")
        while True:
            ccConfirm = input("\033[0;31;43m\U000026A0 Are you sure you want to remove all other CC VMs? Please answer YES or NO (case sensitive)\U000026A0 :\033[0m ")
            if ccConfirm == "YES":
                break
            elif ccConfirm == "NO":
                print("Aborted")
                sys.exit()
                break
            else:
                print("Incorrect input, please try again (Please answer YES or NO)!")

# Construct base URL
base_url = "https://connector." + cloudName + "/api/v1/"

def obfuscateApiKey (apiKey):
    seed = apiKey
    now = int(time.time() * 1000)
    n = str(now)[-6:]
    r = str(int(n) >> 1).zfill(6)
    key = ""
    for i in range(0, len(str(n)), 1):
        key += seed[int(str(n)[i])]
    for j in range(0, len(str(r)), 1):
        key += seed[int(str(r)[j])+2]
 
    return key

headers = {'Content-Type':'application/json'}
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def createSession(username, password, apiKey):
    auth_url = base_url + 'auth'
    now = int(time.time() * 1000)
    payload = {'apiKey': obfuscateApiKey(apiKey), 'username': username, 'password':password, 'timestamp': now  }
    s = requests.Session()
    # Added verify=False to bypass ZCC certificate otherwise call may fail with unable to verify SSL cert for certain cloud
    r = s.post(auth_url,data=json.dumps(payload),headers=headers, verify=False)
    return s

# Get CC Groups
def getConnectorGroup(s):
    ccgroup_url = base_url + 'ecgroup'
    list_of_ccgroups = s.get(ccgroup_url, headers=headers)
    if vpcID is None:
        return list_of_ccgroups.json()
    else:
        filtered_list = []
        for cGroups in list_of_ccgroups.json():
            if vpcID in cGroups['name']:
                filtered_list.append(cGroups)
        return filtered_list

# Delete Cloud Connector VM
def deleteConnector(s,ccGroupID,vmID):
    ccgroup_url = base_url + 'ecgroup/' + str(ccGroupID) + '/vm/' + str(vmID)
    print(ccgroup_url)
    delete_cc = s.delete(ccgroup_url, headers=headers)
    return delete_cc

# Activate Changes
def forcedActivate(s):
    forced_activation_url = base_url + 'ecAdminActivateStatus/forcedActivate'
    activation_status = s.put(forced_activation_url, headers=headers)
    return activation_status

f = createSession(username, password, apiKey)

connectorGroups = getConnectorGroup(f)

# Double Confirm
print("The following CC VMs will be DELETED.")
for cGroups in connectorGroups:
    ccGroupID = cGroups['id']
    # Cycle through the list of VMs in the CC group
    for vm in range(len(cGroups['ecVMs'])):
        if (cGroups['ecVMs'][vm]['name']) in ccID:
            continue
        else:
            print(cGroups['ecVMs'][vm]['name'], end=' (')
            print (cGroups['ecVMs'][vm]['id'], end=')\n')

while True:
    ccConfirm = input("Are you sure you wish to continue? Please answer YES or NO (case sensitive): ")
    if ccConfirm == "YES":
        break
    elif ccConfirm == "NO":
        print("Aborted")
        sys.exit()
        break
    else:
        print("Incorrect input, please try again (Please answer YES or NO)!")
    
# Cycle through the list of VMs in the CC group
for cGroups in connectorGroups:
    if ccConfirm == "YES":
        ccGroupID = cGroups['id']
        for vm in range(len(cGroups['ecVMs'])):
            if (cGroups['ecVMs'][vm]['name']) in ccID:
                continue
            else:
                print ("Removing Cloud Connector VM:")
                print(cGroups['ecVMs'][vm]['name'], end=' (')
                print (cGroups['ecVMs'][vm]['id'], end=')\n')
                vmID = cGroups['ecVMs'][vm]['id']
                # Make the API call to delete the VM
                delete_result = deleteConnector(f,ccGroupID=ccGroupID,vmID=vmID)
                # Successful delete should return 204 otherwise 400/405
                print(delete_result)
                # Sleeping for 1s to avoid too many API request
                time.sleep(1)

# Force activate after changes
#print("Activating Changes")
#print(forcedActivate(f).text)