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
Return 					; End automatic execution




;===============================================================================
; Labels
;===============================================================================

RemoveToolTip:
{
	SetTimer,, off
	ToolTip
	Return
}
ReadyStatus:
{
	SetTimer,, off
	GuiControl,, % hStatus, Ready
	Return
}

ClearProgress:
{
	SetTimer,, Off
	GuiControl,,LoopProgress, 0
	Return
}

AdaptersDDL: 
{
	Gui, Submit, NoHide
	GuiControl,, % hSelectedAdapter, % AdaptersDDL
	GuiControlGet, AdaptersDDL
	AdapterIndex := GetAdapterIndex(AdaptersDDL)
	Return
}
	
ModemsDDL:
{
	GuiControlGet, ModemsDDL
	scriptNames := ""
	scriptFolder := A_WorkingDir "\Scripts\" ModemsDDL "\"
	Loop, Files, % scriptFolder "\*", F
	{
		SplitPath, A_LoopFileName, name1, dir1, ext1, name_no_ext1, drive1
		scriptNames .= "|" name_no_ext1
	}
	
	scriptNames .= "||"
	
	ScriptDDL := ""
	GuiControl,, ScriptDDL, % scriptNames
	GuiControl, -Disabled, scriptDDL
	GuiControl, -Disabled, Connect
	
	Gosub, ScriptDDL
	Return
}

ScriptDDL:
{
	GuiControlGet, ModemsDDL
	GuiControlGet, ScriptDDL
	GuiControlGet, Gateway
	GuiControlGet, Useable
	GuiControlGet, SubnetsDDL
	GuiControlGet, DNS1
	GuiControlGet, DNS2
	ripkey := Presets.rip
	host := Presets.host
	
	file := A_WorkingDir "\Scripts\" ModemsDDL "\" ScriptDDL ".txt"
	FileRead, script, % file
	If (ValidIP(Gateway))
	{
		StringSplit, Octets, Gateway, .
		Octets4--
		If (Octets4 < 0 )
			Octets4 := 255	
		Network := Octets1 "." Octets2 "." Octets3 "." Octets4
		script := StrReplace(script, "[GATEWAY]", Gateway)
		script := StrReplace(script, "[NETWORK]", Network)
	}
	
	If (ValidIP(Useable))
		script := StrReplace(script, "[USEABLE]", Useable)
	script := StrReplace(script, "[SUBNET]", SubnetsDDL)
	script := StrReplace(script, "[DNS1]", DNS1)
	script := StrReplace(script, "[DNS2]", DNS2)
	script := StrReplace(script, "[RIPKEY]", ripkey)
	script := StrReplace(script, "[HOST_NAME]", host)
	
	GuiControl,, ScriptText, % script
	Return
}

GW_Label:
{
	;GuiControl,, % hUseable, 10.120.166.230
	;Return
	GuiControlGet, Gateway
	If (ValidIP(Gateway)) {
		StringSplit, Octets, Gateway, .
		Octets4++
		If (Octets4 >=256)
			Octets4 := 0
		
		GuiControl,, Useable, %Octets1%.%Octets2%.%Octets3%.%Octets4%
	}
	Return
}

ChangeDefaults:
{
	GuiSettings()
	Return
}

2GuiClose:
{
	Gui, 1:-Disabled
	Gui, 2:Destroy
	Return	
}

NetInfo:
{
	Run, rundll32.exe shell32.dll`,Control_RunDLL ncpa.cpl
	Return
}

UseableIP_Label:
{
	Return
}

WinMoveMsgBox:
{
	If WinExist(WinName)
		SetTimer, WinMoveMsgBox, OFF
	WinMove, %WinName%, , %WinX%, %WinY%
	Return
}

;===============================================================================
; Button Events
;===============================================================================

ButtonPINGGATEWAY:
{
	GuiControlGet, Gateway
	If (ValidIP(Gateway)) {
		target := "CMD.lnk /C ping /t " . Gateway
		Run, %target%, %A_WorkingDir%
	} Else {
		setStatus("Invalid Gateway IP")
		tToolTip("Invalid Gateway IP")
	}
	Return
}

ButtonSTATIC:
{
	GuiControlGet, AdaptersDDL
	GuiControlGet, Useable
	GuiControlGet, SubnetsDDL
	GuiControlGet, Gateway
	GuiControlGet, DNS1
	GuiControlGet, DNS2
	
	If (ValidIP(Gateway) && ValidIP(Useable))
	{
		width := 220
		;WinGetPos, X, Y,,, A
		WinGetActiveStats, Title, W, H, X, Y
		WinX := X+(W/2)-(width/2)
		WinY := Y+100
		WinName := "Set Static?"
		SetTimer, WinMoveMsgBox, 20
		Gui +OwnDialogs
		MsgBox, 308, %WinName%, Set a Static IP on this PC?`n`nIP= %Useable%
		IfMsgBox Yes
		{
			GuiControl,, % hStatus, Setting local static...
			;~ Powershell works well for setting static
			
			;cmdArgs := " /c netsh interface ipv4 set address " AdaptersDDL " static " Useable " " SubnetsDDL " " GateWay " & netsh interface ipv4 set dns " AdaptersDDL " static " DNS1 " & netsh interface ipv4 add dns " AdaptersDDL " addr=" DNS2 " index=2"
			;Run, *RunAs %comspec% %cmdArgs%,,hide
			
			CIDR := GetCIDR(SubnetsDDL)
			psArgs := "New-NetIPAddress -InterfaceIndex " AdapterIndex " -IPAddress " Useable " -PrefixLength " CIDR " -DefaultGateway " Gateway " `; Set-DnsClientServerAddress -InterfaceIndex " AdapterIndex " -ServerAddresses """ DNS1 " , " DNS2 """"
			Run, *RunAS PowerShell.exe -Command %psArgs%,, Hide
			
			iCount := 10
			Loop, %iCount% 
			{
				Position := 100/iCount * A_Index
				GuiControl,, LoopProgress, % Position
				Sleep, 100
			}
			SetTimer, ClearProgress, -500
			SetTimer, ReadyStatus, -500
			;GuiControl,, LocalIP, % GetIPByAdaptor(AdaptersDDL)
		}
	}
	Else {
		setStatus("IP is not Valid")
		tToolTip("IP is not Valid")
	}
	Return
}

ButtonDHCP:
{
	width := 220
	;WinGetPos, X, Y,,, A
	WinGetActiveStats, Title, W, H, X, Y
	WinX := X+(W/2)-(width/2)
	WinY := Y+100
	WinName := "Set DHCP?"
	SetTimer, WinMoveMsgBox, 20
	Gui +OwnDialogs
	MsgBox, 308, %WinName%, Set DHCP on this PC?
	IfMsgBox Yes
	{
		
		;~ WMI seems to work best for DHCP
		GuiControl,, % hStatus, Setting local DHCP...
		wmiDHCPArgs := "$adapter = Get-WmiObject win32_NetworkAdapterConfiguration -Filter 'IPEnabled = true' `; $adapter.SetDNSServerSearchOrder() `; $adapter.EnableDHCP()"
		Run, *RunAs PowerShell.exe -Command %wmiDHCPArgs%,, Hide
		;psArgs := "Set-NetIPInterface -InterfaceAlias" AdaptersDDL " -Dhcp Enabled"
		;Run, *RunAs PowerShell.exe -Command Set-DnsClientServerAddress -InterfaceIndex %AdapterIndex% -ResetServerAddresses `; Set-NetIPInterface -InterfaceAlias %AdaptersDDL% -Dhcp Enabled,,Hide
		;args := " /c netsh interface ipv4 set address " AdaptersDDL " dhcp"
		;Run, *RunAs %comspec% %args%
		
		iCount := 10
		Loop, %iCount% 
		{
			Position := 100/iCount * A_Index
			GuiControl,, LoopProgress, % Position
			Sleep, 100
		}
		SetTimer, ClearProgress, -500
		SetTimer, ReadyStatus, -500
		;GuiControl,, LocalIP, % GetIPByAdaptor(AdaptersDDL)
	}
	Return
}

ButtonCreateTunnel:
{
	GuiControlGet, TenDot
	If (ValidIP(TenDot)) {
		width := 220
		;WinGetPos, X, Y,,, A
		WinGetActiveStats, Title, W, H, X, Y
		WinX := X+(W/2)-(width/2)
		WinY := Y+100
		WinName := "Create Tunnel?"
		SetTimer, WinMoveMsgBox, 20
		Gui +OwnDialogs
		MsgBox, 308, %WinName%, Create tunnel to:`n     %TenDot%
		IfMsgBox Yes
		{		
			GuiControl,, % hStatus, Setting up HTTP tunnel...
			jb := 
			Process, Close, %tunnelPID%
			fileName := A_WorkingDir "\KiTTY\KiTTY.exe"
			loginArg := "-ssh " JumpBox[jb].address " -P " JumpBox[jb].port " -l " JumpBox[jb].user " -pw " JumpBox[jb].pw
			tunnelArg := "-L 80:" TenDot ":80 -L 8080:" TenDot ":8080"
			target := fileName " " loginArg " " tunnelArg
			
			Run, %target%, %A_WorkingDir%\KiTTY, Minimize Hide, tunnelPID
			
			iCount := 10
			Loop, %iCount% 
			{
				Position := 100/iCount * A_Index
				GuiControl,, LoopProgress, % Position
				Sleep, 100
			}
			SetTimer, ClearProgress, -500
			SetTimer, ReadyStatus, -500
		}
	} Else {
		setStatus("Invalid 10(dot) IP")
		tToolTip("Invalid 10(dot) IP")
	}
	Return
}

ButtonConnecttoModem:
{
	GuiControlGet, TenDot
	If (ValidIP(TenDot)) {
		jb := 3
		width := 220
		;WinGetPos, X, Y,,, A
		WinGetActiveStats, Title, W, H, X, Y
		WinX := X+(W/2)-(width/2)
		WinY := Y+200
		WinName := "Connect to Modem"
		SetTimer, WinMoveMsgBox, 20
		Gui +OwnDialogs
		MsgBox, 4, %WinName%, Connet to Jumpbox?
		IfMsgBox, Yes
		{
			;connect to Jumpbox over ssh
			fileName := A_WorkingDir "\KiTTY\KiTTY.exe"
			loginArg := "-ssh " JumpBox[jb].address " -P " JumpBox[jb].port " -l " JumpBox[jb].user " -pw " JumpBox[jb].pw
			target := fileName " " loginArg 
			Run, %target%, %A_WorkingDir%\KiTTY,, sshPID
			
			; send telnet command to Jumpbox which will connect to the modem
			
			width := 220
			;WinGetPos, X, Y,,, A
			WinGetActiveStats, Title, W, H, X, Y
			WinX := X+(W/2)-(width/2)
			WinY := Y+200
			WinName := "Telnet to Modem"
			SetTimer, WinMoveMsgBox, 20
			Gui +OwnDialogs			
			;MsgBox,0,Telnet, When Ready: Press Ok to Telnet to modem.
			MsgBox,0,Telnet, Wait for Jump Box to Connect!`n`nClick OK to Telnet to %TenDot%`n`nUsername:`ttechnician`nPassword:`t(Copied to Clipboard)
			IfMsgBox, OK
			{
				IF ProcessExist(sshPID) 
					sendText := "telnet " TenDot
					WinActivate, ahk_pid %sshPID%
					Sleep, 100
					SendInput %sendText%{Enter}
					;Send {Enter}
				}
			}
		}
	}
	Else {
		setStatus("Invalid 10(dot) IP")
		Gui +OwnDialogs
		tToolTip("Invalid 10(dot) IP")
	}
	Return
}
ButtonRefresh: 
{
	Gosub, ScriptDDL
	
	Return
}

ButtonCopy:
{
	GuiControlGet, ScriptText
	Clipboard := ScriptText
	setStatus("Copied to Clipboard")
	Return
}
;===============================================================================
; Functions
;===============================================================================

OnLoad() {
	Global ; Assume-global mode
	Static Init := OnLoad() ; Call function
	
	I_Icon = %A_WorkingDir%\images\Spectrum.ico
	IfExist, %I_Icon%
	Menu, Tray, Icon, %I_Icon%
	Menu, Tray, Tip, SMB ToolBox
	
	Gui, 9:+AlwaysOnTop -Caption
	Gui, 9:Margin, 10, 10
	Gui, 9:Add, Picture,, %A_WorkingDir%\images\splash_400x127.png
	Gui, 9:Show
	
	Sleep, 1000
	Gui,  9:Destroy
	
	;Presets := {"d1": "24.97.208.121", "d2": "24.97.208.122", "rip": "auth#rip", "host": "SPECTRUM"}
	Presets := {"d1": "8.8.8.8", "d2": "8.8.4.4", "rip": "auth#rip", "host": "SPECTRUM"}
	ReplaceValue := {"net": "[NETWORK]", "gw": "[GATEWAY]", "use": "[USEABLE]", "sub": "[SUBNET]", "d1": "[DNS1]", "d2": "[DNS2]", "rip": "[RIPKEY]", "host": "[HOSTNAME]"}
	
	JumpBox := []
	JumpBox[1] := {"name": "NorthEast 1", "address": "24.24.43.132", "port": "22", "user": "bctechcpe", "pw": "T3chBCcp3"}
	JumpBox[2] := {"name": "NorthEast 2", "address": "24.24.43.133", "port": "22", "user": "bctechcpe", "pw": "T3chBCcp3"}
	JumpBox[3] := {"name": "Test Box", "address": "192.168.1.202", "port": "22", "user": "technician", "pw": "technician"}
	
	If (FileExist(A_Temp "\NetInfo.txt")) {
		FileDelete, %A_Temp%\NetInfo.txt
	}
	
}

OnUnload(ExitReason, ExitCode) {
	Global ; Assume-global mode
	
	Process, Close, %tunnelPID%
	Process, Close, %sshPID%
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
	
	;Gui, +AlwaysOnTop +LastFound -Resize +HWNDhGui
	Gui, +LastFound -Resize +HWNDhGui
	Gui, Margin, 10, 10
	Gui, Font, S11 CDefault Normal, Courier
	
	; Top Row 0
	Gui, Font, S11 CDefault Bold, Arial
	Gui, Add, Text, x%xCol_1% y%yTop_Row0_Text% w140 h20, Select Adapter:
	Gui, Font, S10 CDefault Normal, Arial
	Gui, Add, DropDownList, x%xCol_1% y%yTop_Row0_Obj% w220 vAdaptersDDL gAdaptersDDL
	Gui, Add, Picture, x500 y25 w25 h25 Icon36 gChangeDefaults, C:\WINDOWS\SYSTEM32\SHELL32.dll
	
	;Gui, Add, Picture, x+20 y25 w30 h30 Icon89 gNetInfo , C:\WINDOWS\SYSTEM32\SHELL32.dll
	
	Gui, Font, S8 CDefault Normal, Courier
	Gui, Add, Text, x%xCol_3% y10 w160 h15 +Right vLocalIP 
	
	; Top Row 1
	Gui, Font, S9 CDefault Normal, Arial
	Gui, Add, Text, x%xCol_1% y%yTop_Row1_Text% w80 h20, Gateway:
	Gui, Add, Text, x%xCol_2% yp w140 h20, Usable:
	Gui, Add, Text, x%xCol_3% yp w140 h20, SubnetMask:
	Gui, Font, S11 CDefault Normal, Courier
	Gui, Add, Edit, x%xCol_1% y%yTop_Row1_Obj% w160 HWNDhGateway gGW_Label vGateway +Center
	Gui, Add, Edit, x%xCol_2% yp w160 HWNDhUseable gUseableIP_Label vUseable +Center
	Gui, Add, DropDownList, x%xCol_3% yp w160 vSubnetsDDL, 255.255.255.252||255.255.255.248|255.255.255.240|255.255.255.0
	
	; Top Row 2
	Gui, Font, S9 CDefault Normal, Arial
	Gui, Add, Text, x%xCol_1% y%yTop_Row2_Text% w140 h20 , RIP Key:
	Gui, Add, Text, x%xCol_2% y%yTop_Row2_Text% w140 h20, DNS 1:
	Gui, Add, Text, x%xCol_3% y%yTop_Row2_Text% w140 h20, DNS 2:
	Gui, Font, S11 CDefault Normal, Courier
	Gui, Add, Edit, x%xCol_1% y%yTop_Row2_Obj% w160 HWNDhRipKey +ReadOnly +Center, % Presets.rip
	Gui, Add, Edit, x%xCol_2% y%yTop_Row2_Obj% w160 HWNDhDNS1 vDNS1 +ReadOnly +Center, % Presets.d1
	Gui, Add, Edit, x%xCol_3% y%yTop_Row2_Obj% w160 HWNDhDNS2 vDNS2 +ReadOnly +Center, % Presets.d2
	
	; Top Button Row
	Gui, Font, S10 CDefault Bold, Arial
	xButtonCol_1 := xCol_1 + 10
	Gui, Add, Button, x%xButtonCol_1% y%yTop_Row3_Button% w140 h25, PING GATEWAY
	Gui, Add, Button, x250 y%yTop_Row3_Button% w100 h25, STATIC
	Gui, Add, Button, x%xCol_3% y%yTop_Row3_Button% w100 h25, DHCP
	Gui, Add, Picture, x505 yp w20 h20 Icon89 gNetInfo, C:\WINDOWS\SYSTEM32\SHELL32.dll
	
	; Vertical Line
	Gui,  Add, Text, xm y%ySeperateTop% w520 0x10
	
	; Mid Row1
	Gui, Font, S9 CDefault Normal, Arial
	Gui, Add, Text, x%xCol_1% y%yMid_Row1_Text% w160 h20, Modem IP - 10(dot):
	Gui, Add, Text, x%xCol_2% y%yMid_Row1_Text% w160 h20 , Modem Model:
	Gui, Add, Text, x%xCol_3% y%yMid_Row1_Text% w160 h20 , Script:
	Gui, Font, S11 CDefault Normal, Courier
	Gui, Add, Edit, x%xCol_1% y%yMid_Row1_Obj% w160 vTenDot +Center	
	; Gui, Font, S11 CDefault Normal, Arial
	Gui, Add, DropDownList, x%xCol_2% y%yMid_Row1_Obj% w160 vModemsDDL gModemsDDL +Disabled
	Gui, Add, DropDownList, x%xCol_3% y%yMid_Row1_Obj% w160 vScriptDDL gScriptDDL +Disabled, <-- Select Modem||
	
	Gui, Font, S10 CDefault Bold, Arial
	xButtonCol_1 := xCol_1 + 20
	Gui, Add, Button, x%xButtonCol_1% y+25 w120 h25, Create Tunnel
	Gui, Add, Button, x%xCol_2% yp w340 h25 vConnect +Disabled, Connect to Modem
	
	; Vertical Line
	Gui,  Add, Text, xm y+15 w520 0x10
	
	; Edit box for Script
	Gui, Font, S8 CDefault Bold, Arial
	Gui, Add, Button, x%xCol_1% y+1 w80 h20, Refresh
	Gui, Add, Button, x+10 yp w60 h20, Copy
	Gui, Font, S11 CDefault Normal, Courier
	; Gui, Font, S11 CDefault Normal, Arial
	Gui, Add, Edit, x%xCol_1% y+5 h200 w520 HWNDhScriptText vScriptText vscroll
	
	; Status
	Gui, Add, Text, x%xCol_1% y+10 w250 HWNDhStatus,
	; Progress Bar
	Gui Add, Progress, x+20 yp w250 h20 vLoopProgress Border, 0
	Gui, Font, c666666
	GuiControl, Font, % hStatus
	
	;Gui, Show, x2000 y40 w540, SMB ToolBox
	Gui, Show, w540, SMB ToolBox
	
	; Get Adapters
	GuiControl,, % hStatus, Getting Adapters...
	GuiControl, +Disabled, AdaptersDDL
	RunWait, PowerShell.exe Get-NetAdapter | Format-Table -Property Name | Out-File -FilePath %A_Temp%\NetInfo.txt -Width 300,, Hide
	
	Adapters := ""
	
	;get file length for Progress bar
	FileRead, Text, %A_Temp%\NetInfo.txt
	Loop, Parse, Text, `n, `r
		Lines := A_Index
	Lines--
	
	Loop, Read, %A_Temp%\NetInfo.txt
	{
		Position := 100/Lines * A_Index
		GuiControl,, LoopProgress, % Position
		Sleep, 50
		
		If (A_Index < 4 || A_LoopReadLine = "" || Instr(A_LoopReadLine, "Bluetooth")) {
			Continue
		}
		
		aName := Trim(A_LoopReadLine)
		If (aName = "Ethernet")
			Adapters .= RegexReplace(A_LoopReadLine, "^\s+|\s+$") "||"
		Else
			Adapters .= RegexReplace(A_LoopReadLine, "^\s+|\s+$") "|"
	}
	
	If (FileExist(A_Temp "\NetInfo.txt")) {
		FileDelete, %A_Temp%\NetInfo.txt
	}
	
	
	GuiControl,, AdaptersDDL, % Adapters
	GuiControl, -Disabled, AdaptersDDL
	GuiControlGet, AdaptersDDL
	AdapterIndex := GetAdapterIndex(AdaptersDDL)
	;GuiControl,, LocalIP, % GetIPByAdaptor(AdaptersDDL)
	
	; Get Modem Names
	GuiControl, +Disabled, ModemsDDL
	
	modemNames := ""
	scriptFolder := A_WorkingDir "\Scripts"
	Loop, Files, % scriptFolder "\*", D
	{
		SplitPath, A_LoopFileName, name1, dir1, ext1, name_no_ext1, drive1 
		modemNames .= name1 "|"
	}
	GuiControl,, ModemsDDL, % modemNames
	GuiControlGet, AdaptersDDL
	GuiControl, -Disabled, ModemsDDL
	
	SetTimer, ClearProgress, -100
	SetTimer, ReadyStatus, -100
	Return
}

GuiSettings()
{
	width := 300
	;WinGetPos, X, Y,,, A
	WinGetActiveStats, Title, W, H, X, Y
	X := X+(W/2)-(width/2)
	Y := Y+100
	
	Gui, 1:+Disabled
	Gui, 2:+AlwaysOnTop +LastFound -Resize +HWNDh2Gui
	Gui, 2:+Owner
	Gui, 2:Margin, 10, 10
	Gui, 2:Font, S20 CDefault Bold, Courier
	
	Gui, 2:Add, Text, x10 w280 +Center, TODO: Add Settings Menus
	Gui, 2:Show, w%width% h100 x%X% y%Y%, Default Settings
	
	Return
}
GuiClose(GuiHwnd) {
	ExitApp ; Terminate the script unconditionally
}

GuiEscape(GuiHwnd) {
	ExitApp ; Terminate the script unconditionally
}

GetIPByAdaptor(adaptorName) {
	objWMIService := ComObjGet("winmgmts:{impersonationLevel = impersonate}!\\.\root\cimv2")
	colItems := objWMIService.ExecQuery("SELECT * FROM Win32_NetworkAdapter WHERE NetConnectionID = '" adaptorName "'")._NewEnum, colItems[objItem]
	colItems := objWMIService.ExecQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE InterfaceIndex = '" objItem.InterfaceIndex "'")._NewEnum, colItems[objItem]
	
	Return objItem.IPAddress[0]
}

GetCIDR(sub){
	If (ValidIP(sub)) {
		StringSplit, Octets, sub, .
		arrSubnet := {0:24, 128:25, 192:26, 224:27, 240:28, 248:29, 252:30, 254:31, 255:32}
		Return arrSubnet[Octets4]
	}
	Return 0
}

GetAdapterIndex(ad){
	
	RunWait, PowerShell.exe Get-NetAdapter -Name %ad% | Format-List -Property IfIndex | Out-File -FilePath %A_Temp%\NetInfo.txt -Width 300,, Hide
	Loop, read, %A_Temp%\NetInfo.txt
	{
		strPos := InStr(A_LoopReadLine, ":")
		If (strPos != 0) {
			StringRight, iPos, A_LoopReadLine, StrLen(A_LoopReadLine)-strPos
			iPos := Trim(iPos)
			Break
		}	
	}
	
	If (FileExist(A_Temp "\NetInfo.txt")) {
		FileDelete, %A_Temp%\NetInfo.txt
	}
	
	Return, iPos
}

ValidIP(a) {
	Loop, Parse, a, .
	{
		If A_LoopField is digit
			If A_LoopField between 0 and 255
				e++
		c++
	}
	Return, e = 4 AND c = 4
}

tToolTip(tip) {
	ToolTip, %tip%
	time := -2000
	SetTimer, RemoveToolTip, %time%
	return
}

setStatus(msg) {
	global
	GuiControl,, % hStatus, % msg
	SetTimer, ReadyStatus, -1500
}

ProcessExist(Name){
	Process, Exist, %Name%
	Return Errorlevel
}
;===============================================================================
; Hotkeys
;===============================================================================

!F3::
If ProcessExist(sshPID)
{
	MsgBox, I see it
}


Return

;===============================================================================
