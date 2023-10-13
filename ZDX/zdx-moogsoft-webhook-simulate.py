
import requests

#Webhook
endpoint_url = 'your-endpoint-url-here' # https://api.moogsoft.ai/express/v1/integrations/custom/64fb724636934057e6c7d859
api_key = 'your-api-key-here'

data = {
        "event": "Zscaler-ZDX",
        "version": "1.1",
        "alertId": "7276532158385666244",
        "ruleName": "Dynamic Alerting Network",
        "severity": "High",
        "status": "STARTED",
        "startTime": "1694198288",
        "createTime": "1694199666",
        "endTime": "1694199666",
        "criteria": {
            "op": "and",
            "conditions": [
                {
                    "conditionString": "(MTR Latency >= 300 ms)",
                    "stats": {
                        "min": 513,
                        "avg": 513,
                        "max": 513
                    },
                    "isHit": 1
                },
                {
                    "conditionString": "(ZDX Score drop sensitivity = High)",
                    "stats": "1694199666",
                    "isHit": 1
                }
            ]
        },
        "zdxUrl": "https://admin.zdxcloud.net/zdx/admin/alerts/7276532158385666244",
        "criteriaString": "((MTR Latency >= 300 ms), actual stats: min = 513.0, avg = 513.0, max = 513.0, criteria satisfied ) AND ((ZDX Score drop sensitivity = High), criteria satisfied )",
        "text": "Rule Name: Dynamic Alerting Network;\nAlert ID: 7276532158385666244 | \nZDX URL: https://admin.zdxcloud.net/zdx/admin/alerts/7276532158385666244 | \nAlert Status: STARTED | \nAlert Severity: 1 | \nCriteria: ((MTR Latency >= 300 ms), actual stats: min = 513.0, avg = 513.0, max = 513.0, criteria satisfied ) AND ((ZDX Score drop sensitivity = High), criteria satisfied ) |\nImpacted:  1 Geolocations |\n1 Departments |\n1 OS Versions |\n1 Devices |\n1 Zscaler Locations",
        "message": "Alert ID: 7276532158385666244 | Alert Status: Started | Rule Name: Dynamic Alerting Network ",
        "description": "Alert ID: 7276532158385666244 | Alert Status: Started |  Rule Name: Dynamic Alerting Network | Alert Severity: High | Criteria: ((MTR Latency >= 300 ms), actual stats: min = 513.0, avg = 513.0, max = 513.0, criteria satisfied ) AND ((ZDX Score drop sensitivity = High), criteria satisfied ) | ZDX-URL: https://admin.zdxcloud.net/zdx/admin/alerts/7276532158385666244 |\nImpacted:  1 Geolocations |\n1 Departments |\n1 OS Versions |\n1 Devices |\n1 Zscaler Locations",
        "alias": "Zscaler-ZDX",
        "zloc_count": "1",
        "alertType": "Network",
        "impactedDeviceCount": 1,
        "geolocationCount": 1,
        "deptCount": 1,
        "osverCount": 1
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

