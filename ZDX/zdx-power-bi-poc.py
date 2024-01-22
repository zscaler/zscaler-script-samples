import requests
import pandas as pd
import io
import hashlib
import time
import json

from datetime import datetime, timezone
from urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)
headers = {'Content-Type' : 'application/json', 'accept' : 'application/json'}

timestamp = int(time.time())
payload = {
    'key_id': 'YOUR-KEY-ID-HERE',
    'key_secret': hashlib.sha256(("YOUR-SECRET-HERE:" +
                                   str(timestamp)).encode()).hexdigest(),
    'timestamp': timestamp
}

# print(payload)

response = requests.post('https://api.zdxcloud.net/v1/oauth/token',verify=False, headers=headers, data=json.dumps(payload))

# print(response)

accessToken = "<invalid>"
accessToken = response.json()['token']

headers = {'Content-Type' : 'application/json', 'accept' : 'application/json',
          'Authorization': "Bearer " + accessToken}

response = requests.get('https://api.zdxcloud.net/v1/apps', verify=False, headers=headers)
print(response.json())
#data = pd.DataFrame.from_dict(response.json())
apps = pd.DataFrame.from_dict(response.json())
print(apps)
