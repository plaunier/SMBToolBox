#SingleInstance, Force	; Allow only one running instance of script
;#Persistent 			; Keep the script permanently running until terminated
;#NoEnv 				; Avoid checking empty variables for environment variables
;#Warn 					; Enable warnings to assist with detecting common errors
;#NoTrayIcon 			; Disable the tray icon of the script
;#KeyHistory, 0 		; Keystroke and mouse click history
;ListLines, Off 		; The script lines most recently executed
;SetWorkingDir, % A_ScriptDir ; Set the working directory of the script
SetBatchLines, -1 		; The speed at which the lines of the script are executed
SendMode, Input 		; The method for sending keystrokes and mouse clicks
;DetectHiddenWindows, On	; The visibility of hidden windows by the script
;SetWinDelay, 0 		; The delay to occur after modifying a window
;SetControlDelay, 0 	; The delay to occur after modifying a control
OnExit("OnUnload") 		; Run a subroutine or function when exiting the script
return 					; End automatic execution




;===============================================================================
; Labels
;===============================================================================

AdaptersDDL: 
{
	Gui, Submit, NoHide
	GuiControl,, % hSelectedAdapter, % AdaptersDDL
	GuiControl, -ReadOnly, % hGateway
	;GuiControl, -ReadOnly, % hUseable
	GuiControl,, % hRipKey, % Presets.rip
	GuiControl,, % hDNSServer1, % Presets.d1
	GuiControl,, % hDNSServer2, % Presets.d2
	
	return
}

ModemsDDL:
{
	return
}

ScriptDDL:
{
	return
}

GatewayEdit:
{
	MsgBox test
	;GuiControl, -ReadOnly, % hGateway
	return
}

ButtonSTATIC:
{
	
	return
}

ButtonDHCP:
{
	;run, %ComSpec% /c netsh interface ip set address "%SelectedAdapter%" dhcp,,hide
	
	return
}

ButtonRefresh:
{
	GuiControlGet, AdaptersDDL
	GuiControl,, ScriptText, Selected Adaptor= %AdaptersDDL%
	return
}
;===============================================================================
; Functions
;===============================================================================

OnLoad() {
	Global ; Assume-global mode
	Static Init := OnLoad() ; Call function
	
	Menu, Tray, Tip, BC ToolBox
	
	Presets := {"d1": "8.8.8.8", "d2": "8.8.4.4", "rip": "auth#rip", "host": "SPECTRUM"}
	;Presets := {"d1": "24.97.208.121", "d2": "24.97.208.122", "rip": "auth#rip", "host": "SPECTRUM"}
	ReplaceValue := {"NET": "[NETWORK]", "GW": "[GATEWAY]", "USE": "[USEABLE]", "SUB": "[SUBNET]", "D1": "[DNS1]", "D2": "[DNS2]", "RIP": "[RIPKEY]", "HOST": "[HOSTNAME]"}
	
	If (FileExist(A_Temp "\NetInfo.txt")) {
		FileDelete, %A_Temp%\NetInfo.txt
	}
	
}

OnUnload(ExitReason, ExitCode) {
	Global ; Assume-global mode
}

GuiCreate() {
	Global ; Assume-global mode
	Static Init := GuiCreate() ; Call function
	
	xCol_1 := 10
	xCol_2 := 190
	xCol_3 := 370
	
	yTop_Row0_Text := 10
	yTop_Row0_Obj := 30
	
	yTop_Row1_Text := 70
	yTop_Row1_Obj := 87
	yTop_Row2_Text := yTop_Row1_Text + 50
	yTop_Row2_Obj := yTop_Row1_Obj + 50
	yTop_Row3_Button := yTop_Row2_Text + 65
	
	ySeperateTop := yTop_Row3_Button + 42
	yMid_Row1_Text := ySeperateTop + 20
	yMid_Row1_Obj := yMid_Row1_Text + 17
	
	Gui,  +AlwaysOnTop
	Gui, +LastFound -Resize +HWNDhGui
	Gui, Margin, 10, 10
	Gui, Font, S11 CDefault Normal, Courier
	
	; Top Row 0
	Gui, Font, S11 CDefault Bold, Arial
	Gui, Add, Text, x%xCol_1% y%yTop_Row0_Text% w140 h20, Select Adapter:
	Gui, Font, S10 CDefault Normal, Arial
	Gui, Add, DropDownList, x%xCol_1% y%yTop_Row0_Obj% w220 vAdaptersDDL gAdaptersDDL
	
	; Top Row 1
	Gui, Font, S9 CDefault Normal, Arial
	Gui, Add, Text, x%xCol_1% y%yTop_Row1_Text% w80 h20, Gateway:
	Gui, Add, Text, x%xCol_2% yp w140 h20 , Usable:
	Gui, Add, Text, x%xCol_3% yp w140 h20, SubnetMask:
	Gui, Font, S11 CDefault Normal, Courier
	Gui, Add, Edit, x%xCol_2% y%yTop_Row1_Obj% w160 HWNDhGateway gGatewayEdit +ReadOnly +Center
	Gui, Add, Edit, x%xCol_1% yp w160 HWNDhUseable +ReadOnly +Center
	Gui, Add, DropDownList, x%xCol_3% yp w160 vSubnetsDDL, 255.255.255.252||255.255.255.248|255.255.255.240
	
	; Top Row 2
	Gui, Font, S9 CDefault Normal, Arial
	Gui, Add, Text, x%xCol_1% y%yTop_Row2_Text% w140 h20 , RIP Key:
	Gui, Add, Text, x%xCol_2% y%yTop_Row2_Text% w140 h20, DNS 1:
	Gui, Add, Text, x%xCol_3% y%yTop_Row2_Text% w140 h20, DNS 2:
	Gui, Font, S11 CDefault Normal, Courier
	Gui, Add, Edit, x%xCol_1% y%yTop_Row2_Obj% w160 HWNDhRipKey +ReadOnly +Center
	Gui, Add, Edit, x%xCol_2% y%yTop_Row2_Obj% w160 HWNDhDNSServer1 +ReadOnly +Center
	Gui, Add, Edit, x%xCol_3% y%yTop_Row2_Obj% w160 HWNDhDNSServer2 +ReadOnly +Center
	
	; Top Button Row
	Gui, Font, S10 CDefault Bold, Arial
	xButtonCol_1 := xCol_1 + 10
	Gui, Add, Button, x%xButtonCol_1% y%yTop_Row3_Button% w140 h25, PING GATEWAY
	Gui, Add, Button, x250 y%yTop_Row3_Button% w100 h25, STATIC
	Gui, Add, Button, x%xCol_3% y%yTop_Row3_Button% w100 h25, DHCP
	
	; Vertical Line
	Gui,  Add, Text, xm y%ySeperateTop% w520 0x10
	
	; Mid Row1
	Gui, Font, S9 CDefault Normal, Arial
	Gui, Add, Text, x%xCol_1% y%yMid_Row1_Text% w160 h20 , (10 dot) IP:
	Gui, Add, Text, x%xCol_2% y%yMid_Row1_Text% w160 h20 , Modem Model:
	Gui, Add, Text, x%xCol_3% y%yMid_Row1_Text% w160 h20 , Script:
	Gui, Font, S11 CDefault Normal, Courier
	Gui, Add, Edit, x%xCol_1% y%yMid_Row1_Obj% w160 vTenDot +Center	
	; Gui, Font, S11 CDefault Normal, Arial
	Gui, Add, DropDownList, x%xCol_2% y%yMid_Row1_Obj% w160 vModemsDDL gModemsDDL 
	Gui, Add, DropDownList, x%xCol_3% y%yMid_Row1_Obj% w160 vScriptDDL gScriptDDL +ReadOnly
	
	Gui, Font, S10 CDefault Bold, Arial
	xButtonCol_1 := xCol_1 + 20
	Gui, Add, Button, x%xButtonCol_1% y+25 w120 h25, Create Tunnel
	Gui, Add, Button, x%xCol_2% yp w340 h25, Connect to Modem
	;Gui, Add, Button, x%xCol_3% y%yTop_Row3_Button% w100 h25, DHCP
	
	; Vertical Line
	Gui,  Add, Text, xm y+15 w520 0x10
	
	; Edit box for Script
	Gui, Font, S8 CDefault Bold, Arial
	Gui, Add, Button, x%xCol_1% y+1 w80 h20, Refresh
	Gui, Font, S11 CDefault Normal, Courier
	; Gui, Font, S11 CDefault Normal, Arial
	Gui, Add, Edit, x%xCol_1% y+5 h200 w520 HWNDhScriptText vScriptText vscroll
	
	; Status
	Gui, Add, Text, xm y+20 w160 HWNDhStatus,
	Gui, Font, c666666
	GuiControl, Font, % hStatus
	Gui, Show, Autosize, SMB ToolBox
	
	
	; Get Adaptors
	GuiControl,, % hStatus, Getting Adapters...
	GuiControl, +Disabled, AdaptersDDL
	RunWait, PowerShell.exe Get-NetAdapter | Format-Table -Property Name | Out-File -FilePath %A_Temp%\NetInfo.txt -Width 300,, Hide
	
	Adapters := ""
	
	Loop, Read, %A_Temp%\NetInfo.txt
	{
		If (A_Index < 4 || A_LoopReadLine = "") {
			Continue
		}
		
		Adapters .= RegexReplace(A_LoopReadLine, "^\s+|\s+$") "|"
	}
	
	If (FileExist(A_Temp "\NetInfo.txt")) {
		FileDelete, %A_Temp%\NetInfo.txt
	}
	
	Sort, Adapters, UD|
	GuiControl,, AdaptersDDL, % Adapters
	GuiControl, -Disabled, AdaptersDDL
	GuiControl,, % hStatus, Ready
	
	
	return
}


GuiClose(GuiHwnd) {
	ExitApp ; Terminate the script unconditionally
}

GuiEscape(GuiHwnd) {
	ExitApp ; Terminate the script unconditionally
}
;===============================================================================
; Hotkeys
;===============================================================================

!PAUSE::Reload

;===============================================================================
