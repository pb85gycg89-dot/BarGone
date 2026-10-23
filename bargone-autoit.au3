#NoTrayIcon ; Optional: Hides the AutoIt tray icon
#include <WindowsConstants.au3>
#include <Date.au3> ; Required for _Date_Time_GetTickCount()

Opt("GUIOnEventMode", 1)

; --- Global State Variables ---
Global $ghHookKeyboard = 0
Global $g_bWinKeyDown = False
Global $g_iStayVisibleUntil = 0
Global $g_hStub_KeyProc = DllCallbackRegister("_KeyProc", "long", "int;wparam;lparam")
Global $g_hUser32 = DllOpen("user32.dll")
Global $g_hKernel32 = DllOpen("kernel32.dll")

; --- Main Entry Point ---
OnAutoItExitRegister("OnExit")
_SetupKeyboardHook()
_MainLoop()

Func _MainLoop()
	Local $hPrimaryTaskbar, $hSecondaryTaskbar
    Local $bShouldShow, $iCurrentTime
    While 1
        ; 1. Check if the taskbar should currently be visible
        $iCurrentTime = _Date_Time_GetTickCount()
        $bShouldShow = $g_bWinKeyDown Or ($iCurrentTime < $g_iStayVisibleUntil)

        ; 2. Find Windows Taskbar Handles (Primary and Secondary Monitors)
        $hPrimaryTaskbar = WinGetHandle("[CLASS:Shell_TrayWnd]")
        $hSecondaryTaskbar = WinGetHandle("[CLASS:Shell_SecondaryTrayWnd]")

        ; 3. Enforce the visibility state aggressively
        If $bShouldShow Then
            If $hPrimaryTaskbar Then DllCall($g_hUser32, "bool", "ShowWindow", "hwnd", $hPrimaryTaskbar, "int", 4) ; 4 = SW_SHOWNOACTIVATE
            If $hSecondaryTaskbar Then DllCall($g_hUser32, "bool", "ShowWindow", "hwnd", $hSecondaryTaskbar, "int", 4)
        Else
            If $hPrimaryTaskbar Then DllCall($g_hUser32, "bool", "ShowWindow", "hwnd", $hPrimaryTaskbar, "int", 0) ; 0 = SW_HIDE
            If $hSecondaryTaskbar Then DllCall($g_hUser32, "bool", "ShowWindow", "hwnd", $hSecondaryTaskbar, "int", 0)
        EndIf

        Sleep(30) ; Prevent high CPU utilization
    WEnd
EndFunc

; --- Pure Low-Level Keyboard Hook (No include dependencies) ---
Func _SetupKeyboardHook()
    Local $aModule = DllCall($g_hKernel32, "hwnd", "GetModuleHandle", "ptr", 0)
    If @error Then Exit

    ; Call SetWindowsHookEx directly from user32.dll (WH_KEYBOARD_LL = 13)
    Local $aHook = DllCall($g_hUser32, "hwnd", "SetWindowsHookEx", _
            "int", 13, _
            "ptr", DllCallbackGetPtr($g_hStub_KeyProc), _
            "hwnd", $aModule[0], _
            "dword", 0)

    If @error Or $aHook[0] = 0 Then
        MsgBox(16, "Error", "Failed to install low-level keyboard hook.")
        Exit
    EndIf
    $ghHookKeyboard = $aHook[0]
EndFunc

; --- Hook Callback Procedure ---
Func _KeyProc($nCode, $wParam, $lParam)
	If $nCode >= 0 Then
        Local $tKEYHOOKSTRUCT = DllStructCreate("dword vkCode;dword scanCode;dword flags;dword time;ulong_ptr dwExtraInfo", $lParam)
        Local $vkCode = DllStructGetData($tKEYHOOKSTRUCT, "vkCode")

        ; VK_LWIN = 0x5B, VK_RWIN = 0x5C
        If $vkCode = 0x5B Or $vkCode = 0x5C Then
            ; WM_KEYDOWN = 0x0100 or WM_SYSKEYDOWN = 0x0104
            If $wParam = 0x0100 Or $wParam = 0x0104 Then
                $g_bWinKeyDown = True

            ; WM_KEYUP = 0x0101 or WM_SYSKEYUP = 0x0105
            ElseIf $wParam = 0x0101 Or $wParam = 0x0105 Then
                $g_bWinKeyDown = true
                ; Give a 400ms grace period on release just like the Jai code
                $g_iStayVisibleUntil = _Date_Time_GetTickCount() + 400
            EndIf
        EndIf
    EndIf

    ; Pass the event along down the chain so the Start Menu actually opens
    Local $aRet = DllCall($g_hUser32, "long_ptr", "CallNextHookEx", "hwnd", $ghHookKeyboard, "int", $nCode, "wparam", $wParam, "lparam", $lParam)
    Return $aRet[0]
EndFunc

; --- Cleanup on Exit ---
Func OnExit()
    If $ghHookKeyboard Then DllCall($g_hUser32, "bool", "UnhookWindowsHookEx", "hwnd", $ghHookKeyboard)
    If $g_hStub_KeyProc Then DllCallbackFree($g_hStub_KeyProc)
    DllClose($g_hUser32)
    DllClose($g_hKernel32)

    ; Restore taskbars to default visible layout when the program ends
    Local $hPrimaryTaskbar = WinGetHandle("[CLASS:Shell_TrayWnd]")
    Local $hSecondaryTaskbar = WinGetHandle("[CLASS:Shell_SecondaryTrayWnd]")
    If $hPrimaryTaskbar Then WinSetState($hPrimaryTaskbar, "", @SW_SHOW)
    If $hSecondaryTaskbar Then WinSetState($hSecondaryTaskbar, "", @SW_SHOW)
EndFunc
