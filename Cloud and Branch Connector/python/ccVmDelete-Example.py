# Import Required Modules
import time, requests, json, urllib3, getpass

# Variables
cloudName = input("Cloud Name (e.g. zscloud.net): ")
username = input("Username: ")
password = getpass.getpass("Password: ")
apiKey = input("APIKey: ")
ccGroupID = input("Enter the Cloud or Branch Connector Group ID: ")
vmID = input("Enter the VM ID of the Cloud or Branch Connector within the Group ID specified previously: ")

# Construct base URL
base_url = "https://connector." + cloudName + "/api/v1/"

# Obfuscate API Key
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

# Create Session to CC Portal
def createSession(username, password, apiKey):
   auth_url = base_url + 'auth'
   now = int(time.time() * 1000)
   payload = {'apiKey':obfuscateApiKey(apiKey), 'username':username, 'password':password, 'timestamp':now  }
   s = requests.Session()
   # Added verify=False to bypass ZCC certificate otherwise call may fail with unable to verify SSL cert for certain cloud
   r = s.post(auth_url,data=json.dumps(payload),headers=headers, verify=False)
   return s

# Delete BC/CC
def deleteConnector(s):
    ccgroup_url = base_url + 'ecgroup/' + ccGroupID + '/vm/' + vmID
    list_of_ccgroups = s.delete(ccgroup_url, headers=headers)
    return list_of_ccgroups.json()

# Activate Changes
def activateChanges(s):
    activation_url = base_url + 'ecAdminActivateStatus/activate'
    activation_status = s.put(activation_url, headers=headers)
    return activation_status

f = createSession(username, password, apiKey)
delete_result = deleteConnector(f)

# Display deletion status
print("\nDeletion Status:")
print(delete_result)

# Display activation status
print("\nActivation Status:")
print(activateChanges(f).text)