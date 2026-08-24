$dt=get-date -Format "MM-dd-yyyy-hhmm"

# District 1
Start-Transcript -Path ".\logs\District1\$dt.log"
Sync-ChromebooksFromGoogleToAeries -config ConfigName -verbose
Sync-CBDataFromAeriesToGoogle -config ConfigName -verbose
Stop-Transcript

# District 2
Start-Transcript -Path ".\logs\District2\$dt.log"
Sync-ChromebooksFromGoogleToAeries -config ConfigName -verbose
Sync-CBDataFromAeriesToGoogle -config ConfigName -verbose
Stop-Transcript