﻿Set-PSFConfig -Module 'T2Tscripts' -Name 'Client.Uri' -Value $null -Initialize -Validation 'string' -Description "Url to connect to the T2Tscripts Azure function"
Set-PSFConfig -Module 'T2Tscripts' -Name 'Client.UnprotectedToken' -Value '' -Initialize -Validation 'string' -Description "The unencrypted access token to the T2Tscripts Azure function. ONLY use this from secure locations or non-sensitive functions!"
Set-PSFConfig -Module 'T2Tscripts' -Name 'Client.ProtectedToken' -Value $null -Initialize -Validation 'credential' -Description "An encrypted access token to the T2Tscripts Azure function. Use this to persist an access token in a way only the current user on the current system can access."