while ($true) {
    
    # Variable Range
    #$numbers = 3600, 7200, 10800
    $numbers = 3600
    #$numbers = 15600, 19600, 21600 
    #$numbers = 3600
    $sleepTime1 = $numbers | Get-Random 
    $sleepTime2 = $numbers | Get-Random
    
    # Connec to Poor-Wifi, Start Clumsy and Wait and then Kill it after some time
    #Start-Process -FilePath "C:\Users\eve\Desktop\Signal Value DB Degrade.bat" 
    Write-Host "*******Connecting to Poor Wifi******"
    netsh wlan connect ssid=3Com_Wifi name=3Com_Wifi; Start-Sleep -Seconds 6
    Write-Host ("Current time: " + (Get-Date -Format 'HH:mm'))
    Write-Host ("Staying connected for " + $sleepTime2/60/60 + " hours")
    
    # Slow the network part using Clumsy 
    $slow_clumsy_options = 200, 600, 400, 700, 100, 20, 5, 250, 150, 60 
    $slowdown = $slow_clumsy_options | Get-Random 
    $var1 = "C:\clumsy\clumsy.exe"
    $var2 = "--filter outbound --lag on --lag-time " + $slowdown
    $var3 = $slowdown
    start-process $var1 $var2 
    # END Slow the network part using CLumsy


    
    Start-Sleep -Seconds $sleepTime2
    netsh wlan disconnect
    Start-Sleep -Seconds 15


    
    # Connect to Good-Wifi
    stop-process -name "clumsy" -Force
    Write-Host "*******Connecting to GOOD Wifi******";
    netsh wlan connect ssid=Google_Nest name=Google_Nest; Start-Sleep -Seconds 6
    #Write-Host "*******Time remaining: 30 minutes ******"

    Write-Host ("Current time: " + (Get-Date -Format 'HH:mm'))
    Write-Host ("Staying connected for " + $sleepTime1/60/60 + " hours")
    Start-Sleep -Seconds $sleepTime1
    netsh wlan disconnect
    Start-Sleep -Seconds 15
            

}
