# Import Required Modules
import time
import requests
import json
import urllib3
import getpass

# Variables
cloudName = input("Cloud Name (e.g. zscloud.net): ")
username = input("Username: ")
password = getpass.getpass("Password: ")
apiKey = input("APIKey: ")
updUsername = input("Enter the user name of the Admin to update (e.g. Admin User): ")
userID = input("Enter the user ID of the Admin to update (e.g. 12345): ")
updPassword = getpass.getpass("Enter the Admin user's updated password: ")
updLoginName = input("Enter the Admin user's updated login name (e.g. admin@zscaler.com): ")
updEmail = input("Enter the Admin user's updated email address (e.g. admin@zscaler.com): ")
updRole = input("Enter the Admin user's updated role assignment (e.g. Super Admin): ")
updRoleID = input("Enter the role ID associated with the role assigned to the Admin user in the previous step: ")


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
def createSessionCC(username, password, apiKey):
   auth_url = base_url + 'auth'
   now = int(time.time() * 1000)
   payload = {'apiKey':obfuscateApiKey(apiKey), 'username':username, 'password':password, 'timestamp':now  }
   s = requests.Session()
   # Added verify=False to bypass ZCC certificate otherwise call may fail with unable to verify SSL cert for certain cloud
   r = s.post(auth_url,data=json.dumps(payload),headers=headers, verify=False)
   return s

# Update Admin User
def updateAdmin(s):
   add_url = base_url + 'adminUsers/' + userID
   payload = {'userName':updUsername, 'loginName':updLoginName, 'password':updPassword, 'email':updEmail, 'role':{'id': updRoleID, 'name': updRole}}
   create_status = s.put(add_url,data=json.dumps(payload, separators=(',', ':')),headers=headers)
   return create_status

# Activate Changes
def activateChanges(s):
    activation_url = base_url + 'ecAdminActivateStatus/activate'
    activation_status = s.put(activation_url, headers=headers)
    return activation_status

f = createSessionCC(username, password, apiKey)

# Add user and display creation status
print("\nCreation Status:")
print(updateAdmin(f).text)

# Display activation status
print("\nActivation Status:")
print(activateChanges(f).text)
