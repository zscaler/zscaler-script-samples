import hashlib
import json
import time
import requests
from urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)
headers = {'Content-Type': 'application/json', 'accept': 'application/json'}
timestamp = int(time.time())
payload = {
    'key_id': 'Your-Key-Here',
    'key_secret': hashlib.sha256(("Your-secret-here:" +
                                  str(timestamp)).encode()).hexdigest(),
    'timestamp': timestamp
}

response = requests.post('https://api.zdxcloud.net/v1/oauth/token',
                         verify=False, headers=headers, data=
                         json.dumps(payload))
if response.status_code == 200:
    accessToken = response.json()['token']
else:
    print("Failed with status code: {}".format(response.status_code))
headers = {'Content-Type': 'application/json', 'accept': 'application/json',
           'Authorization': "Bearer " + accessToken}

url = "https://api.zdxcloud.net/v1/analysis"

payload = json.dumps({
  "device_id": "52756968", # device ID 
  "app_id": "20", # App ID 
  "t0": 1690380000, # Start time in Epoch
  "t1": 1690380300  # End time in Epoch
})

response = requests.request("POST", url, headers=headers, data=payload)

# Get the value of "analysis_id"
analysis_id_value = response.json()["analysis_id"]

# Print the result
print("Y-Engine Analysis ID Created:", analysis_id_value)

y_engine_url = "https://api.zdxcloud.net/v1/analysis/" + analysis_id_value
#print(y_engine_url)

y_engine_result_response = requests.get(y_engine_url, verify=False, headers=headers)
print("Waiting 15 seconds for Y-Engine Analysis to complete")
time.sleep(15)
print("Fetching YEngine Results ... ")
print(y_engine_result_response.json())
