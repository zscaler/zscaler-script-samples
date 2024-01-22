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
