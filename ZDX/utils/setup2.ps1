Invoke-WebRequest -Uri  https://github.com/jagt/clumsy/releases/download/0.3/clumsy-0.3-win64-a.zip -UseBasicParsing -OutFile 'C:\\clumsy.zip'
Expand-Archive -Path 'C:\\clumsy.zip' -DestinationPath 'C:\\clumsy\\' -Force
Invoke-WebRequest -Uri  https://raw.githubusercontent.com/zscaler/zscaler-script-samples/main/ZDX/utils/k-v2.ps1 -UseBasicParsing -OutFile 'C:\\Users\\eve\\Desktop\\k-v2.ps1'
Invoke-WebRequest -Uri  https://raw.githubusercontent.com/zscaler/zscaler-script-samples/main/ZDX/utils/sigdegrade.py change main  -UseBasicParsing -OutFile 'C:\\Users\\eve\\PycharmProjects\\ktest\\main.py'
