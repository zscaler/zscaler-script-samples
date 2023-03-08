# Import Required Modules
import time, requests, json, urllib3, getpass

# Variables
cloudName = input("Cloud Name (e.g. zscloud.net): ")
username = input("Username: ")
password = getpass.getpass("Password: ")
apiKey = input("APIKey: ")
newUsername = input("Enter the new user's name (e.g. Admin User): ")
newLoginName = input("Enter the new user's login ID (e.g. admin@zscaler.com): ")
newPassword = getpass.getpass("Enter the new user's password: ")
newEmail = input("Enter the new user's email address (e.g. admin@zscaler.com): ")
newRole = input("Enter the new user's role assignment (e.g. Super Admin): ")
newRoleID = input("Enter the role ID associated with the role assigned to this user: ")

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

# Create Admin User
def createAdmin(s):
   add_url = base_url + 'adminUsers'
   payload = {'userName':newUsername, 'loginName':newLoginName, 'password':newPassword, 'email':newEmail, 'role':{'id': newRoleID, 'name': newRole}}
   create_status = s.post(add_url,data=json.dumps(payload, separators=(',', ':')),headers=headers)
   return create_status

# Activate Changes
def activateChanges(s):
    activation_url = base_url + 'ecAdminActivateStatus/activate'
    activation_status = s.put(activation_url, headers=headers)
    return activation_status

f = createSessionCC(username, password, apiKey)

# Add user and display creation status
print("\nCreation Status:")
print(createAdmin(f).text)

# Display activation status
print("\nActivation Status:")
print(activateChanges(f).text)
