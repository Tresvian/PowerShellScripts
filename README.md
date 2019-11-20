# PowerShellScripts
PowerShell scripts for System Administration tasks. Grabbed only a handful from work place with FOUO data redacted.

Most of the scripts feature mass pushes using PSexec, winRM, RPC, etc. Uses Active Directory and pinging to verify, and checks prereqs of running machine to make sure it's good to go.

Some use DRA API using REST to get things working, and they're often used around my area. Those are very extensively covered by my scripts.

The most creative one is the DiscoverP.ps1 script that grabs all printer IPs in a given AD grab. Very useful if there's a common naming convention in place.
