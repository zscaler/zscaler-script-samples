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
    data = list_of_ccgroups.json()
    from pprint import pprint
    #pprint(data, depth=2, indent=2[0])
    vm_ids_per_group = {}
    for group in data:
        group_id = group['id']
        # Use f-string to convert response to iterable string.
        # 2 print options
        #print(f"Group: {group.get('id')} {group['name']}")
        vm_key = "ecVMs"
        if vm_key in group and group[vm_key]:
            vms = group[vm_key]
            ids = [ vm["id"] for vm in vms] 
            vm_ids_per_group[group_id] = ids

    pprint(vm_ids_per_group)









    #for cc in list_of_ccgroups.json():
    #    print(cc)
    #with open('json_test.json', 'w') as file:
    #    json.dump(cc, file)



    # Return filtered list (only INACTIVE appliances)
 #   for cGroups in list_of_ccgroups.json():
 #       for vm in range(len(cGroups['ecVMs'])):
 #           if cGroups['ecVMs'][vm]['operationalStatus'] == 'INACTIVE':
 #               filtered_list_of_ccgroups.append({cGroups['id'] : cGroups['ecVMs'][vm]['id']}) 
 #   return list_of_ccgroups

f = createSession(username, password, apiKey)
g = getConnectorGroup(f)