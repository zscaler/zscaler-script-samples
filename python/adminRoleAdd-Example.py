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
newRoleName = input("Enter the new role name: ")
apiMgmt = input("API Key Management Permission? Please answer READ_ONLY, READ_WRITE, or NONE (case sensitive): ")
cloudProv = input("Cloud Connector Provisioning Permission? Please answer READ_ONLY, READ_WRITE, or NONE (case sensitive): ")
locMgmt = input("Location Management Permission? Please answer READ_ONLY, READ_WRITE, or NONE (case sensitive): ")
ecDash = input("Dashboard Access Permission? Please answer READ_ONLY, or NONE (case sensitive): ")
ecFwd = input("Traffic Forwarding Policy Permission? Please answer READ_ONLY, READ_WRITE, or NONE (case sensitive): ")
ecTmplt = input("Location Template Permission? Please answer READ_ONLY, READ_WRITE, or NONE (case sensitive): ")
remoteMgmt = input("Remote Management Permission? Please answer READ_WRITE, or NONE (case sensitive): ")
adminMgmt = input("Admin User Management Permission? Please answer READ_ONLY, READ_WRITE, or NONE (case sensitive): ")
nssMgmt = input("NSS Logging Configuration Permission? Please answer READ_WRITE, or NONE (case sensitive): ")

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

# Create Admin Role
def createRole(s):
   add_url = base_url + 'adminRoles'
   payload = {
       'rank':'7',
            'name':newRoleName,
            'policyAccess':'NONE',
            'alertingAccess':'READ_ONLY',
            'dashboardAccess':'NONE',
            'reportAccess':'NONE',
            'analysisAccess':'NONE',
            'usernameAccess':'NONE',
            'deviceInfoAccess':'NONE',
            'adminAcctAccess':'READ_WRITE',
            'featurePermissions':{
            'APIKEY_MANAGEMENT':apiMgmt,
            'EDGE_CONNECTOR_CLOUD_PROVISIONING':cloudProv,
            'EDGE_CONNECTOR_LOCATION_MANAGEMENT':locMgmt,
            'EDGE_CONNECTOR_DASHBOARD':ecDash,
            'EDGE_CONNECTOR_FORWARDING':ecFwd,
            'EDGE_CONNECTOR_TEMPLATE':ecTmplt,
            'REMOTE_ASSISTANCE_MANAGEMENT':remoteMgmt,
            'EDGE_CONNECTOR_ADMIN_MANAGEMENT':adminMgmt,
            'EDGE_CONNECTOR_NSS_CONFIGURATION':nssMgmt
            },
        'roleType':'EDGE_CONNECTOR_ADMIN'
        }
   create_status = s.post(add_url,data=json.dumps(payload, separators=(',', ':')),headers=headers)
   return create_status

# Activate Changes
def activateChanges(s):
    activation_url = base_url + 'ecAdminActivateStatus/activate'
    activation_status = s.put(activation_url, headers=headers)
    return activation_status

f = createSessionCC(username, password, apiKey)

# Add role and display creation status
print("\nCreation Status:")
print(createRole(f).text)

# Display activation status
print("\nActivation Status:")
print(activateChanges(f).text)
