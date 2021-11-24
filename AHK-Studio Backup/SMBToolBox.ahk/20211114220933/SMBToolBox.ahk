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
	Return
}

ScriptDDL:
{
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
	Gui, 2:+AlwaysOnTop +LastFound -Resize -Caption
	Gui, 2:Margin, 10, 10
	Gui, 2:Font, S20 CDefault Bold, Courier
	
	Gui, 2:Add, Text, x10 w280 +Center, TODO: Add Settings Menus
	Gui, 2:Show, w300 h100
	
	Sleep, 1500
	Gui,  2:Destroy
	
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

;===============================================================================
; Button Events
;===============================================================================

ButtonPINGGATEWAY:
{
	GuiControlGet, Gateway
	If (ValidIP(Gateway)) {
		target := "CMD.lnk /C ping /t " . Gateway
		Run, %target%, %A_WorkingDir%
	} Else 
		setStatus("Invalid Gateway IP")
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
		GuiControl,, % hStatus, Setting local static...
		Gui +OwnDialogs
		MsgBox,308,Set Static?,Set a Static IP on this PC?`n%Useable%
		IfMsgBox Yes
		{
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
	Return
}

ButtonDHCP:
{
	MsgBox,308,Set DHCP?,Set DHCP on this PC?
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
		Process, Close, %tunnelPID%
		fileName := A_WorkingDir "\KiTTY\KiTTY.exe"
		loginArg := "-ssh " JumpBox[1].address " -P " JumpBox[1].port " -l " JumpBox[1].user " -pw " JumpBox[1].pw
		tunnelArg := "-L 80:" TenDot ":80 -L 8080:" TenDot ":8080"
		target := fileName " " loginArg " " tunnelArg
		
		Run, %target%, %A_WorkingDir%\KiTTY, Minimize Hide, tunnelPID
	} Else 
		setStatus("Invalid 10(dot) IP")
	Return
}

ButtonRefresh: 
{
	GuiControlGet, AdaptersDDL
	GuiControl,, ScriptText, Selected Adaptor= %AdaptersDDL%
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
	ReplaceValue := {"NET": "[NETWORK]", "GW": "[GATEWAY]", "USE": "[USEABLE]", "SUB": "[SUBNET]", "D1": "[DNS1]", "D2": "[DNS2]", "RIP": "[RIPKEY]", "HOST": "[HOSTNAME]"}
	
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
	
	Gui, +AlwaysOnTop +LastFound -Resize +HWNDhGui
	Gui, Margin, 10, 10
	Gui, Font, S11 CDefault Normal, Courier
	
	; Top Row 0
	Gui, Font, S11 CDefault Bold, Arial
	Gui, Add, Text, x%xCol_1% y%yTop_Row0_Text% w140 h20, Select Adapter:
	Gui, Font, S10 CDefault Normal, Arial
	Gui, Add, DropDownList, x%xCol_1% y%yTop_Row0_Obj% w220 vAdaptersDDL gAdaptersDDL
	Gui, Add, Picture, x500 y25 w30 h30 Icon36 gChangeDefaults, C:\WINDOWS\SYSTEM32\SHELL32.dll
	
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
	Gui, Add, Picture, x500 yp w25 h25 Icon89 gNetInfo , C:\WINDOWS\SYSTEM32\SHELL32.dll
	
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
	Gui, Add, Text, x%xCol_1% y+10 w250 HWNDhStatus,
	; Progress Bar
	Gui Add, Progress, x+20 yp w250 h20 vLoopProgress Border, 0
	Gui, Font, c666666
	GuiControl, Font, % hStatus
	
	Gui, Show, x2000 y40 w540, SMB ToolBox
	;Gui, Show, w540, SMB ToolBox
	
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
	
	SetTimer, ClearProgress, -1000
	GuiControl,,LoopProgress, 0
	
	;Sort, Adapters, UD|
	GuiControl,, AdaptersDDL, % Adapters
	GuiControl, -Disabled, AdaptersDDL
	GuiControlGet, AdaptersDDL
	AdapterIndex := GetAdapterIndex(AdaptersDDL)
	;GuiControl,, LocalIP, % GetIPByAdaptor(AdaptersDDL)
	SetTimer, ReadyStatus, -100
	
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
		
		If (Octets4 = 255)
			Return 32
		If (Octets4 = 254)
			Return 31
		If (Octets4 = 252)
			Return 30
		If (Octets4 = 248)
			Return 29
		If (Octets4 = 240)
			Return 28
		If (Octets4 = 224)
			Return 27
		If (Octets4 = 192)
			Return 26
		If (Octets4 = 128)
			Return 25
		If (Octets4 = 0)
			Return 24
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

setStatus(msg) {
	global
	GuiControl,, % hStatus, % msg
	SetTimer, ReadyStatus, -1500
}


;===============================================================================
; Hotkeys
;===============================================================================


;===============================================================================
