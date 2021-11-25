#SingleInstance, Force	; Allow only one running instance of script
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
OnExit("OnUnload") 		; Run a subroutine or function when exiting the script
Return 					; End automatic execution

;===============================================================================
; Labels
;===============================================================================

RefreshPing:
{
	SetTimer,, Off
	GUI, +LastFoundExist	
	If WinExist()
	{
		
		RunWait %comspec% /c ping -n 1 -w 350 %pingURL% >ping.txt,, Hide
		FileReadLine, line3, ping.txt, 3
		FormatTime, now, , hh:mm:ss
		FoundPos := RegExMatch(line3,"Request timed out.")
		If FoundPos
			pingTxt := now "  |  " line3 "`n" PingTxt
		Else {
			FoundPos := RegExMatch(line3,"Reply from")
			If FoundPos
			{
				RegExMatch(line3, "time.*ms", tripTime)
				pingTxt := now "  |  Reply from " pingURL "  |  " tripTime "`n" pingTxt
			}
		}
		GuiControl,, PingEditBox, % pingTxt
		Settimer, RefreshPing, 1000
	}
	Return
}


;===============================================================================
; Functions
;===============================================================================

OnLoad() {
	Global ; Assume-global mode
	Static Init := OnLoad() ; Call function
	pingURL := % A_Args[1]
}

OnUnload(ExitReason, ExitCode) {
	Global ; Assume-global mode
	
	If (FileExist("ping.txt")) {
		FileDelete, ping.txt
	}
}

GuiCreate() {
	Global ; Assume-global mode
	Static Init := GuiCreate() ; Call function
	width := 420
	height := 100
	WinX := 50
	WinY := 50
	
	Gui, +AlwaysOnTop +LastFound -Resize
	Gui, Font, S10 cWhite Normal, Consolas
	Gui, Color,, 0x000000
	Gui, Add, Edit, x0 y0 w%width% h%height% vPingEditBox
	Gui, Show, w%width% h%height% x%WinX% y%WinY%, Pinging Gateway: %pingURL%
	
	SetTimer, RefreshPing, -100
	
	Return	
}

GuiClose(GuiHwnd) {
	ExitApp ; Terminate the script unconditionally
}

GuiEscape(GuiHwnd) {
	ExitApp ; Terminate the script unconditionally
}

