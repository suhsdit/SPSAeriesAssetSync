$dt=get-date -Format "MM-dd-yyyy-hhmm"

# Add -DetailedLogging to any Sync call below for one verbose line per device examined,
# not just per device changed. Off by default: it adds thousands of lines to these
# transcripts. Use it when chasing a single asset.

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