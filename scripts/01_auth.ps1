# =============================================================================
# BLOCK 1 - AUTHENTICATE WITH THE BOLTZ API
# =============================================================================
#
# WHAT THIS DOES
#   The Boltz CLI ships as a single executable, boltz-api.exe, but the installer
#   does not always put it on your PATH. This block hunts for it in the four
#   places it normally lands, stores the full path in $boltz, then logs you in
#   and prints the account the session is bound to.
#
#   Every later block assumes $boltz is set. If you open a new PowerShell
#   window, run this block again first - PowerShell variables do not survive
#   between windows.
#
# RUN THIS: once per PowerShell session, before anything else.
# =============================================================================

$boltz = Get-ChildItem @(
    "$env:USERPROFILE\.boltz",
    "$env:USERPROFILE\bin",
    "$env:LOCALAPPDATA",
    "$env:APPDATA"
) -Recurse -Filter boltz-api.exe -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName

if (-not $boltz) { throw "Could not find boltz-api.exe" }

Write-Host "Found CLI at: $boltz" -ForegroundColor Green

& $boltz auth login
& $boltz auth whoami


# =============================================================================
# WHAT YOU SHOULD SEE IF IT WORKED
# =============================================================================
#
#   Found CLI at: C:\Users\<you>\.boltz\bin\boltz-api.exe
#
#   `auth login` opens your browser (or prints a device code to paste into one).
#   Approve it there, then come back to the terminal.
#
#   `auth whoami` then prints your account and workspace, something like:
#
#       email:        laurencejaboro858@gmail.com
#       workspace:    ws_ofxdZ7MGM889W5ZPN7R4
#
#   The workspace ID is worth writing down - it appears in the web dashboard
#   and is how you find your jobs later.
#
# IF IT FAILS
#
#   "Could not find boltz-api.exe"
#       The CLI is not installed, or it went somewhere unusual. Search wider:
#           Get-ChildItem C:\ -Recurse -Filter boltz-api.exe -ErrorAction SilentlyContinue
#       then set $boltz to whatever that finds.
#
#   Browser does not open
#       Copy the URL the CLI prints and paste it into a browser yourself.
#
#   whoami prints nothing or an error
#       The login did not complete. Run `& $boltz auth login` again.
# =============================================================================
