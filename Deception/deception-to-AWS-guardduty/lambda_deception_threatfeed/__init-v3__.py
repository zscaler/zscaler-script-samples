import os, sys, time, hashlib

_installed = False

def _install_packages(*packages):
    global _installed
    if not _installed:
        _started = time.time()
        os.system("mkdir -p /tmp/packages")
        _packages = " ".join(f"'{p}'" for p in packages)
        print("INSTALLED:")
        os.system(f"{sys.executable} -m pip freeze --no-cache-dir")
        print("INSTALLING:")
        os.system(
            f"{sys.executable} -m pip install "
            f"--no-cache-dir --target /tmp/packages "
            f"--only-binary :all: --no-color "
            f"--no-warn-script-location {_packages}")
        sys.path.insert(0, "/tmp/packages")
        _installed = True
        _ended = time.time()
        globals()["requests"] = __import__("requests")
        globals()["boto3"] = __import__("boto3")

_install_packages("requests", "boto3")

def calc_hash(file_path, algorithm="sha256"):
    hasher = hashlib.new(algorithm)
    with open(file_path, "rb") as file:
        hasher.update(file.read())
    return hasher.hexdigest()

def compare_hash(new_ip_list_path, old_ip_list_path, algorithm="sha256"):
    hash1 = calc_hash(new_ip_list_path, algorithm)
    hash2 = calc_hash(old_ip_list_path, algorithm)
    return hash1 == hash2

def update_threatfeed():
    s3 = boto3.client('s3')
    output = "dec-ip-list.txt"
    dec_url = os.environ['THREATFEED_URL']
    new_list = requests.get(dec_url)
    if not new_list:
        return
    with (open('/tmp/new_list.txt', 'wb') as new_ip_list):
        new_ip_list.write(new_list.content)
    try:
        old_list = s3.download_file(os.environ['OUTPUT_BUCKET'], output, '/tmp/old_list.txt')
        if compare_hash('/tmp/new_list.txt', '/tmp/old_list.txt'):
            print("The files have the same hash. Skipping update...")
            return
        print("The files have different hashes.")
    except Exception as e:
        print(f"{e}: Error fetching file dec-ip-list.txt. Is this the first run? Does the file exist?")
        pass
    print("Updating ThreatFeed...")
    s3.upload_file('/tmp/new_list.txt', os.environ['OUTPUT_BUCKET'], output)
    location = f"https://s3.amazonaws.com/{os.environ['OUTPUT_BUCKET']}/{output}"
    name = os.environ['THREATFEED_NAME']
    guardduty = boto3.client('guardduty')
    new_list = guardduty.list_detectors()
    if len(new_list['DetectorIds']) == 0:
        raise Exception('Failed to read GuardDuty info. Please check if the service is activated')
    detector_id = new_list['DetectorIds'][0]
    try:
        new_list = guardduty.create_threat_intel_set(
            Activate=True,
            DetectorId=detector_id,
            Format='TXT',
            Location=location,
            Name=name
        )

    except Exception as e:
        strError = str(e)
        if "name already exists" in strError:
            found = False
            new_list = guardduty.list_threat_intel_sets(DetectorId=detector_id)
            for setId in new_list['ThreatIntelSetIds']:
                new_list = guardduty.get_threat_intel_set(DetectorId=detector_id, ThreatIntelSetId=setId)
                if name == new_list['Name']:
                    found = True
                    new_list = guardduty.update_threat_intel_set(
                        Activate=True,
                        DetectorId=detector_id,
                        Location=location,
                        Name=name,
                        ThreatIntelSetId=setId
                    )
                    break

            if not found:
                raise

    return new_list

def lambda_handler(event, context):
    update_threatfeed()
    region = context.invoked_function_arn.split(':')[3]
    group = context.log_group_name
    stream = context.log_stream_name
    cw_logs_url = ("https://console.aws.amazon.com/cloudwatch/"f"home?region={region}#logEventViewer:group={group};stream={stream}")
    print(f"CloudWatch Logs can be found here: {cw_logs_url}")

if __name__ == "__main__":
    update_threatfeed()