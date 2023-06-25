#!/usr/bin/env python3

import time, requests, json, sys, urllib3, argparse, getpass

# Grab variables passed from command-line
parser = argparse.ArgumentParser(description='CC Cleanup Script')
parser.add_argument('-u','--username',help='Username', type=str, required=False)
parser.add_argument('-p','--password',help='Password', type=str, required=False)
parser.add_argument('-a','--apikey',help='APIKey', type=str, required=False)
parser.add_argument('-z','--zcloud',help='Cloud URL', type=str, required=False)
args = parser.parse_args()

cloudName = args.zcloud
username = args.username
password = args.password
apiKey = args.apikey

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

# Get filtered (or unfiltered) list of CC VMs and Groups
def getConnectorGroup(s):
    ccgroup_url = base_url + 'ecgroup'
    list_of_ccgroups = s.get(ccgroup_url, headers=headers)
    # Return the entire list if filtering is not required

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

# getConnectorGroup can take an optional vpcID parameter. If missing, it will return all ccGroups and delete all ccGroups. Be as specific as possible.
connectorGroups = getConnectorGroup(f)

# Delete CC VMs
for cGroups in connectorGroups:
    print("Removing Cloud Connector VM:")
    print(cGroups['id'], end=' ')
    ccGroupID = cGroups['id']
    print(cGroups['name'])
    # Cycle through the list of VMs in the CC group
    for vm in range(len(cGroups['ecVMs'])):
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
print("Activating Changes")
print(forcedActivate(f).text)