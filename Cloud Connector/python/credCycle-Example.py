#!/usr/bin/env python3

import time
import requests
import json
import urllib3
import secrets
import string
import getpass

# Variables
cloudName = input("Cloud Name (e.g. zscloud.net): ")
username = input("Username: ")
password = getpass.getpass("Current Password: ")
updPassword = getpass.getpass("NEW Password: ")
apiKey = input("Current APIKey: ")

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
    payload = {'apiKey':obfuscateApiKey(apiKey), 'username':username, 'password':password, 'timestamp':now  }
    s = requests.Session()
    # Added verify=False to bypass ZCC certificate otherwise call may fail with unable to verify SSL cert for certain cloud
    r = s.post(auth_url,data=json.dumps(payload),headers=headers, verify=False)
    return s

# Update Password
def updatePassword(s):
    pass_url = base_url + 'passwordChange'
    payload = {'userName':username,'oldPassword':password,'newPassword':updPassword}
    r = s.post(pass_url,data=json.dumps(payload, separators=(',', ':')),headers=headers, verify=False)
    # If successful, returns HTTP status code 204 with no payload
    return r

# Activate Changes
def activateChanges(s):
    activation_url = base_url + 'ecAdminActivateStatus/activate'
    activation_status = s.put(activation_url, headers=headers)
    return activation_status

f = createSession(username, password, apiKey)

# Print update status
print("\nPassword Update Status")
print(updatePassword(f))

# Display activation status
print("\nActivation Status:")
print(activateChanges(f).text)