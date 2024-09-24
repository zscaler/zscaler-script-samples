"""
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Author: vikas.srivastava@zscaler.com

"""

import hashlib
import json
import time
import requests
import time
from urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)
key_sec = "YOUR_SECRET_HERE:" # Keep the ':'
user = 'SNOW_USERNAME'
pwd = 'SNOW_PASSWORD'
# Setting headers for ZDX API Access
headers = {'Content-Type': 'application/json', 'accept': 'application/json'}
timestamp = int(time.time())

# Your API Key Information here :
payload = {
    'key_id': 'YOUR_KEY_ID_HERE',
    'key_secret': hashlib.sha256((key_sec +
                                  str(timestamp)).encode()).hexdigest(),
    'timestamp': timestamp
}

# Authentication process with ZDX  BEGINS
response = requests.post('https://api.zdxcloud.net/v1/oauth/token',
                         verify=False, headers=headers, data=
                         json.dumps(payload))

if response.status_code == 200:
    accessToken = response.json()['token']
else:
    print("Failed with status code: {}".format(response.status_code))

headers = {'Content-Type': 'application/json', 'accept': 'application/json',
           'Authorization': "Bearer " + accessToken}

# Authentication Process Ends

# Get device list from ZDX
device_list_from_zdx = 'https://api.zdxcloud.net/v1/devices'
device_list_response = requests.get(device_list_from_zdx, verify=False, headers=headers)

# Snow Access
snow_url = 'https://ven05489.service-now.com/api/now/table/cmdb_ci_pc_hardware'

print("You can access a the SNOW CI by SYS_ID Like this : https://ven05489.service-now.com/api/now/table/cmdb_ci_pc_hardware/f9a5620597c835102c9177a71153af4d")

for device in device_list_response.json()['devices']:
    device_id = device['id']
    api_endpoint = 'https://api.zdxcloud.net/v1/devices/'
    api_url = api_endpoint + str(device_id)
    # Get Individual Device Details
    individual_device_details = requests.get(api_url, verify=False, headers=headers)
    hostname = individual_device_details.json()['software']['hostname']
    cpu_model = individual_device_details.json()['hardware']['cpu_model']
    #print(cpu_model)
    time.sleep(1)
    # Parse Hostname and Device ID from the ZDX Output
    print("ZDX Device ID: " + str(device_id) + " and hostname: " + hostname)
    data_ci = '{"name":"%s","attributes":"%s","cpu_name":"%s"}' % (hostname, str(device_id), str(cpu_model))
    #print(data_ci)
    snow_headers = {"Content-Type": "application/json", "Accept": "application/json"}
    # Posting to ServiceNow to create the CI
    response_from_snow = requests.post(snow_url, auth=(user, pwd), headers=snow_headers, data=data_ci)
    if response_from_snow.status_code != 200:
        #print("SUCCESS")
        #print('Status:', response_from_snow.status_code, 'Headers:', response_from_snow.headers, 'Error Response:', response_from_snow.json())
        sys_id_string_data = response_from_snow.json()
        sys_id = sys_id_string_data['result']['sys_id']
        print("CI Created in SNOW " + sys_id) # https://ven05489.service-now.com/api/now/table/cmdb_ci_pc_hardware/634c52c997c475105f803f67f053af6a
