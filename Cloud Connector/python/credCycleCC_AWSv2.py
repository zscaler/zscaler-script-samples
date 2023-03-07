# This script will NOT prompt to confirm updates.
# It will generate a random 16-digit password for the service account specified,
# as well as regenerate the API Key, then update AWS Secrets Manager.

import time, requests, json, urllib3, secrets, string, argparse
from boto3 import Session

# Grab variables passed from command-line
parser = argparse.ArgumentParser(description='CC Credentials Cycle Script')
parser.add_argument('-z','--zcloud',help='Cloud URL', type=str, required=True)
parser.add_argument('-r','--region',help='Region', type=str, required=True)
parser.add_argument('-k','--accesskey',help='Access Key', type=str, required=True)
parser.add_argument('-e','--secretkey',help='Secret Key', type=str, required=True)
parser.add_argument('-n','--secretname',help='Secret Name', type=str, required=True)
args = parser.parse_args()

cloudName = args.zcloud
aws_region_name = args.region
aws_access_id = args.accesskey
aws_secret_key = args.secretkey
aws_secret_name = args.secretname

def generate_password():
    chars = string.ascii_letters + string.digits
    special_chars = '_!/?'
    length = 16

    # Generate random 16-digit alphanumeric password with special characters
    while True:
        passwd = ''.join([secrets.choice(chars) for i in range(length - 1)])
        passwd += secrets.choice(special_chars)
        if (any(s.islower() for s in passwd) and 
            any(s.isupper() for s in passwd) and 
            any(s.isdigit() for s in passwd)):
                break
    
    return passwd

# Update Zscaler components
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

def createSessionCC(username, password, apiKey):
    auth_url = base_url + 'auth'
    now = int(time.time() * 1000)
    payload = {'apiKey':obfuscateApiKey(apiKey), 'username':username, 'password':password, 'timestamp':now  }
    s = requests.Session()
    # Added verify=False to bypass ZCC certificate otherwise call may fail with unable to verify SSL cert for certain cloud
    r = s.post(auth_url,data=json.dumps(payload),headers=headers, verify=False)
    return s

# Activate changes
def forcedActivate(s):
    forced_activation_url = base_url + 'ecAdminActivateStatus/forcedActivate'
    activation_status = s.put(forced_activation_url, headers=headers)
    return activation_status

# Get existing API Key ID
def getAPI(s):
    api_url = base_url + 'apiKeys'
    list_of_apikeys = s.get(api_url, headers=headers)
    return list_of_apikeys.json()

# Get credentials from Secrets Manager
def getCredentials(aws_access_id, aws_secret_key, aws_region_name, aws_secret_name):
    session = Session(
    aws_access_key_id=aws_access_id,
    aws_secret_access_key=aws_secret_key,
    region_name=aws_region_name
    )

    client = session.client(service_name="secretsmanager")

    original_secret = client.get_secret_value(SecretId=aws_secret_name)
    # Return a list containing the client object and secret values dictionary
    # The client object will be used later when updating the secret values
    return [client,json.loads(original_secret["SecretString"])]

# Regenerate API Key
def regenAPI(s,keyid):
    regen_api_url = base_url + 'apiKeys/' + str(keyid) + '/regenerate'
    regen_status = s.post(regen_api_url, headers=headers)
    return regen_status.json()

def updatePassword(s,username, old_password, new_password):
    pass_url = base_url + 'passwordChange'
    payload = {'userName':username,'oldPassword':old_password,'newPassword':new_password}
    r = s.post(pass_url,data=json.dumps(payload, separators=(',', ':')),headers=headers, verify=False)
    # If successful, returns HTTP status code 204 with no payload
    return r

def updateSecrets(client_obj,updated_secrets):
    secrets_client = client_obj
    secrets_client.update_secret(SecretId=aws_secret_name, SecretString=str(json.dumps(updated_secrets)))

#Generate new password
updatedPassword = generate_password()

# Headers for HTTP requests
headers = {'Content-Type':'application/json'}
# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Obtain credentials from Secrets Manager
creds = getCredentials(aws_access_id, aws_secret_key, aws_region_name, aws_secret_name)

# Split the return value from creds into the client object and secret values
secrets_client = creds[0]
secrets_values = creds[1]

f = createSessionCC(secrets_values["username"], secrets_values["password"], secrets_values["api_key"])
api = getAPI(f)

print(f"Regenerating the account password for {secrets_values['username']}...")
pass_update = updatePassword(f, secrets_values["username"], secrets_values["password"],updatedPassword)
print(f"The new password is: {updatedPassword}")

print(f"\nRegenerating the API Key {api[0]['keyValue']}...")
regen_api = regenAPI(f,keyid=api[0]["id"]) 
print(f"The new API key is {regen_api['keyValue']}")

# Force activate after changes
print("\nActivating changes on Cloud Connector portal...")
forcedActivate(f)

# Update AWS Components
# Update the dictionary with new API key and password
secrets_values.update({"api_key": regen_api['keyValue'], "password": updatedPassword})

# Update the secret key
print("\nUpdating AWS Secrets Manager with new credentials...")

updateSecrets(secrets_client,secrets_values)
# secrets_client.update_secret(SecretId=aws_secret_name, SecretString=str(json.dumps(secrets_values)))

print("\nComplete\n")