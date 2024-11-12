# dump-lsass-with-powershell
---
## 1. Introduction
It is a powershell script that bypasses the MDE to generate an LSASS dump. You need administrator privileges to dump. I recommend pypykatz for analyzing dump files.

## 2. Usage
`> .\scripts.ps1 -OutputPath "C:\Users\user\dump.dmp"`

## 3. Reference
- https://cyberdom.blog/defender-for-endpoint-bypassing-lsass-dump-with-powershell/
