import requests
import json

# An API Example which sends data combined for Alert and the Devices. 

endpoint_url = 'your-moogsoft-api-url-here'
api_key = 'your-api-key-here'

data = {

  "id": 7276532158385666244,
  "rule_name": "Dynamic Alerting Network",
  "severity": "1",
  "alert_type": "network",
  "alert_status": "ENDED",
  "application": {
    "id": 18,
    "name": "Salesforce Lightning"
  },
  "geolocations": [
    {
      "id": "4726206.4736286.US",
      "country": "US",
      "city": "San Antonio",
      "state": "Texas",
      "alert_device_dcount": 1
    }
  ],
  "departments": [
    {
      "id": 0,
      "name": "N/A",
      "alert_device_dcount": 1
    }
  ],
  "locations": [
    {
      "id": 4294967293,
      "name": "Road Warrior",
      "alert_device_dcount": 1
    }
  ],
  "started_on": 1694198288,
  "ended_on": 1694201700,
  "devices": [
    {
      "id": 64826272,
      "name": "student(VMware, Inc. VMware Virtual Platform Microsoft Windows 10 Pro;64 bit;amd64)",
      "userid": 69401761,
      "userName": "Quincy Martin",
      "userEmail": "quincy.martin@thezerotrustexchange.com"
    }
  ],
  "next_offset": "NjQ4MjYyNzI="
}

# Define headers
headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'apiKey': api_key
}

# Make the POST request for Webhook
response = requests.post(endpoint_url, headers=headers, json=data)

# Check the response
if response.status_code == 200:
    print("Request was successful.")
    print("Response:", response.json())
else:
    print("Request failed with status code:", response.status_code)
    print("Response:", response.text)

