# ---- TEXT FORMATTING ----
$esc        = [char]0x1B
$boldf      = "${esc}[1m"
$underlinef = "${esc}[4m"
$normf      = "${esc}[0m"

# ---- COPYRIGHT ----
$copyright = @"
    The source code contained herein is provided on an "as is" basis. Brisbane Silicon, Pty Ltd.
    disclaims any and all warranties, whether express, implied, or statutory, including any implied
    warranties of merchantability or of fitness for a particular purpose. In no event shall Brisbane
    Silicon, Pty Ltd. be liable for any incidental, punitive, or consequential damages of any kind
    whatsoever arising from the use of this source code.

    This disclaimer of warranty extends to the user of this source code and user's customers,
    employees, agents, transferees, successors and assigns.

    This is not a grant of patent rights.
"@

# ---- UTILITY FUNCTIONS ----

function Test-SupportedPlatform {
    param([string]$PlatformName)
    $platformPath = "$PlatformsDir\$PlatformName"
    if (Test-Path $platformPath) {
        return $true
    }
    return $false
}
