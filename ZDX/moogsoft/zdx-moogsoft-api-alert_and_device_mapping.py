import hashlib
import json
import time
import requests
from urllib3.exceptions import InsecureRequestWarning
import subprocess

subprocess.run(["clear", "-l"]) 

requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)
headers = {'Content-Type': 'application/json', 'accept': 'application/json'}
timestamp = int(time.time())
payload = {
    'key_id': '7a434742-d3cd-40ad-ad61-c6abdd253a30',
    'key_secret': hashlib.sha256(("zdx-secret-here-with-colon:" +
                                  str(timestamp)).encode()).hexdigest(),
    'timestamp': timestamp
}

response = requests.post('https://api.zdxcloud.net/v1/oauth/token', verify=False, headers=headers, data=json.dumps(payload))

if response.status_code == 200:
    accessToken = response.json()['token']
else:
    print("Failed with status code: {}".format(response.status_code))

headers = {'Content-Type': 'application/json', 'accept': 'application/json', 'Authorization': "Bearer " + accessToken}


def sendToMoogsoft(data):
    endpoint_url = 'moogsoft-api-url-here'
    api_key = 'moogsoft-api-key-here'
    # Define headers
    moog_headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'apiKey': api_key
    }

    # Make the POST request for Webhook
    response = requests.post(endpoint_url, headers=moog_headers, json=data)

    # Check the response
    if response.status_code == 200:
        print("Request was successful.")
        print("Response:", response.json())
    else:
        print("Request failed with status code:", response.status_code)
        print("Response:", response.text)


ongoingAlertDetails = 'https://api.zdxcloud.net/v1/alerts/ongoing'
ongoingAlertDetailsGathered = requests.get(ongoingAlertDetails, verify=False, headers=headers)

for alert in ongoingAlertDetailsGathered.json()['alerts']:
    #print(alert['id'])
    getSpecificAlertDetailsUrl = 'https://api.zdxcloud.net/v1/alerts/' + str(alert['id'])
    getAffectedDevicesUrl = 'https://api.zdxcloud.net/v1/alerts/' + str(alert['id']) + '/affected_devices'
    #print(getSpecificAlertDetailsUrl)
    capturedAlertDetails = requests.get(getSpecificAlertDetailsUrl, verify=False, headers=headers)
    affectedDevicesReceived = requests.get(getAffectedDevicesUrl, verify=False, headers=headers)
    #print(capturedAlertDetails.json())
    #print(affectedDevicesReceived.json())
    merged_json_obj = {**capturedAlertDetails.json(), **affectedDevicesReceived.json()}
    print(merged_json_obj)
    json_formatted_str = json.dumps(merged_json_obj, indent=2)
    print(json_formatted_str)
    sendToMoogsoft(merged_json_obj)
