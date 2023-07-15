"""
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""

import requests
import io
import hashlib
import time
import json
​
from datetime import datetime, timezone
from urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)
headers = {'Content-Type' : 'application/json', 'accept' : 'application/json'}
​
timestamp = int(time.time())
payload = {
    'key_id': 'YOUR_KEY_ID_HERE',
    'key_secret': hashlib.sha256(("YOUR_KEY_SECRETE_HERE:" +
                                   str(timestamp)).encode()).hexdigest(),
    'timestamp': timestamp
} # Leave the ':' after the key secret as it is. 
​
# print(payload)
​
response = requests.post('https://api.zdxcloud.net/v1/oauth/token',
                         verify=False, headers=headers, data=
                         json.dumps(payload))
​
if response.status_code == 200:
    accessToken = response.json()['token']
else:
    print("Failed with status code: {}".format(response.status_code))
​
headers = {'Content-Type' : 'application/json', 'accept' : 'application/json',
          'Authorization': "Bearer " + accessToken}
​
app1 = 'https://api.zdxcloud.net/v1/apps/1/score'
app3 = 'https://api.zdxcloud.net/v1/apps/1/metrics'
app4 = 'https://api.zdxcloud.net/v1/devices'
app5 = 'https://api.zdxcloud.net/v1/users'
​
response = requests.get(app1, verify=False, headers=headers); print (response.json())
response = requests.get(app3, verify=False, headers=headers); print (response.json())
response = requests.get(app4, verify=False, headers=headers); print (response.json())
response = requests.get(app5, verify=False, headers=headers); print (response.json())

