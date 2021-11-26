#SingleInstance, Force	; Allow only one running instance of script
SetBatchLines, -1 		; The speed at which the lines of the script are executed
SendMode, Input 		; The method for sending keystrokes and mouse clicks
DetectHiddenWindows, On	; The visibility of hidden windows by the script
SetTitleMatchMode, 2	; Sets the matching behavior of the WinTitle parameter
OnExit("OnUnload") 		; Run a subroutine or function when exiting the script
Return 					; End automatic execution

;===============================================================================
; Labels
;===============================================================================

RemoveToolTip:
{
	;~ Timer routine to remove tooltip
	SetTimer,, Off
	ToolTip
	Return
}
ReadyStatus:
{
	;~ Timer routine to reset status text in main GUI
	SetTimer,, Off
	GuiControl,, % hStatus, Ready
	Return
}

ClearProgress:
{
	;~ Timer routine to reset the Progress bar on Main GUI
	SetTimer,, Off
	GuiControl,,LoopProgress, 0
	Return
}

WinMoveMsgBox:
{
	;~ Timer routine to move a MsgBox
	If WinExist(WinName)
		SetTimer, WinMoveMsgBox, Off
	WinMove, %WinName%, , %WinX%, %WinY%
	Return
}

ModemsDDL:
{
	;~ Drop Down List routine - Modem Model
	GuiControlGet, ModemsDDL
	scriptNames := ""
	scriptFolder := A_WorkingDir "\Scripts\" ModemsDDL "\"
	;~ Create script drop down list from Scripts directory
	Loop, Files, % scriptFolder "\*", F
	{
		SplitPath, A_LoopFileName, name1, dir1, ext1, name_no_ext1, drive1
		scriptNames .= "|" name_no_ext1
	}
	
	scriptNames .= "||"
	
	ScriptDDL := ""
	GuiControl,, ScriptDDL, % scriptNames
	
	;~ Enable Script selection and Connect Button after first selection
	GuiControl, -Disabled, scriptDDL
	GuiControl, -Disabled, Connect
	
	Gosub, ScriptDDL
	Return
}

ScriptDDL:
{
	;~ Drop Down List Routine - Script
	;~ Parses selected script and fills in the values
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
		;~ Network IP is one less than Gateway
		StringSplit, Octets, Gateway, .
		Octets4--
		If (Octets4 < 0 )
			Octets4 := 255	
		Network := Octets1 "." Octets2 "." Octets3 "." Octets4
		script := StrReplace(script, "[GATEWAY]", Gateway)
		script := StrReplace(script, "[NETWORK]", Network)
	}
	
	;~ Find and Replace remaining values
	If (ValidIP(Useable))
		script := StrReplace(script, "[USEABLE]", Useable)
	script := StrReplace(script, "[SUBNET]", SubnetsDDL)
	script := StrReplace(script, "[DNS1]", DNS1)
	script := StrReplace(script, "[DNS2]", DNS2)
	script := StrReplace(script, "[RIPKEY]", ripkey)
	script := StrReplace(script, "[HOST_NAME]", host)
	
	;~ Put Replaced script into Script Edit Box
	GuiControl,, ScriptText, % script
	Return
}

GW_Label:
{
	;~ Routine when Gateway Edit Box is modified
	GuiControlGet, Gateway
	If (ValidIP(Gateway)) {
		;~ Create a Useable IP one more than Gateway
		StringSplit, Octets, Gateway, .
		Octets4++
		If (Octets4 >=256)
			Octets4 := 0
		;~ Update Useable IP Edit Box
		GuiControl,, Useable, %Octets1%.%Octets2%.%Octets3%.%Octets4%
	}
	Return
}

ChangeDefaults:
{
	;~ Routine when Settings image is clicked.
	GuiSettings()
	Return
}

SettingCancel:
2GuiClose:
{
	;~ OnExit routine when closing Settings GUI
	Gui, 1:-Disabled -AlwaysOnTop
	Gui, 2:Destroy
	Return	
}

NetInfo:
{
	;~ Opens 'Network Connections' Network image is clicked
	Run, rundll32.exe shell32.dll`,Control_RunDLL ncpa.cpl
	Return
}

IPInfo:
{
	;~ Routine when Network Information image is clicked
	;~ Queries network adaptor for current Network information
	for objItem in ComObjGet("winmgmts:\\.\root\CIMV2").ExecQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")
	{
		
		if (objItem.IPAddress[0] = A_IPAddress1)
		{
			WinName := "Network Adapter Info"
			moveMsgBox(340)
			
			Gui +OwnDialogs
			MsgBox, 4096, %WinName%, % "Description:`t" objItem.Description[0] "`n"
						. "IP Address:`t`t" objItem.IPAddress[0] "`n"
						. "IP Subnet:`t`t" objItem.IPSubnet[0] "`n"
						. "IP Gateway:`t`t" objItem.DefaultIPGateway[0] "`n"
						. "DNS-Server:`t`t" objItem.DNSServerSearchOrder[0] "`n"
						. "MAC Address:`t`t" objItem.MACAddress "`n"
						. "DHCP Enabled:`t`t" (objItem.DHCPEnabled[0] ? "Yes" : "No") "`n"
			Break
		}
	}
	Return
}

;===============================================================================
; Button Events
;===============================================================================
ButtonSaveChanges:
{
	;~ Routine when settings Save Button is clicked
	Return
}
ButtonPINGGATEWAY:
{
	;~ Routine when Ping Gateway Button is clicked
	;~ Pings a valid Gateway IP
	GuiControlGet, Gateway
	If !(ValidIP(Gateway)) {
		setStatus("Invalid Gateway IP")
		tToolTip("Invalid Gateway IP")
	} Else {
		;~ run a seperate ahk process to show a custom gui with ping details
		Run, %A_WorkingDir%\include\PingGUI.ahk %Gateway%
	}
	Return
}

ButtonSTATIC:
{
	;~ Routine when the set Static button is clicked
	;~ Sets the active ethernet adapater with a static IP
	;~ After much trial and error between netsh, WMI, and powershell; Powershell is the most relaible in windows 10
	GuiControlGet, Useable
	GuiControlGet, SubnetsDDL
	GuiControlGet, Gateway
	GuiControlGet, DNS1
	GuiControlGet, DNS2
	
	;~ Get the subnet mask (CIDR) of the Subnet
	CIDR := GetCIDR(SubnetsDDL)
	
	If !(ValidIP(Gateway))
	{
		setStatus("Invalid Gateway IP")
		tToolTip("Invalid Gateway IP")
	} Else If !(ValidIP(Useable)) {
		setStatus("Invalid Usable IP")
		tToolTip("Invalid Usable IP")
	} Else {
		msgBoxWidth := 220
		WinName := "Set Static?"
		moveMsgBox(msgBoxWidth)
		Gui +OwnDialogs
		MsgBox, 308, %WinName%, Set a Static IP on this PC?`n`nIP= %Useable%
		IfMsgBox Yes
		{
			GuiControl,, % hStatus, Setting local static...
			Gui, 1:+Disabled +AlwaysOnTop ;~ Disable main gui until the command completes
			RunWait, *RunAS PowerShell.exe -Command $adapter = Get-NetAdapter | ? {$_.Status -eq \""up\""} `; If (($adapter | Get-NetIPConfiguration).IPv4Address.IPAddress) { $adapter | Remove-NetIPAddress -AddressFamily \""IPv4\"" -Confirm:$false } `; If (($adapter | Get-NetIPConfiguration).Ipv4DefaultGateway) { $adapter | Remove-NetRoute -AddressFamily \""IPv4\"" -Confirm:$false } `; $adapter | New-NetIPAddress -AddressFamily \""IPv4\"" -IPAddress \""%Useable%\"" -PrefixLength \""%CIDR%\"" -DefaultGateway \""%Gateway%\""  `; $adapter | Set-DnsClientServerAddress -ServerAddresses \""%DNS1%\""`,\""%DNS2%\"",,Hide
			
			;~ show a status bar progression over 1000ms
			;~ TODO: make this an accurate calculation for the set static routine
			iCount := 10
			Loop, %iCount% 
			{
				Position := 100/iCount * A_Index
				GuiControl,, LoopProgress, % Position
				Sleep, 100
			}
			;~ reenable main gui and reset status
			Gui, 1:-Disabled -AlwaysOnTop
			SetTimer, ClearProgress, -500
			SetTimer, ReadyStatus, -500
		}
	}
	Return
}

ButtonDHCP:
{
	;~ Routine when the set DHCP button is clicked
	;~ Sets the active ethernet adapater to DHCP
	;~ After much trial and error between netsh, WMI, and powershell; Powershell is the most relaible in windows 10
	WinName := "Set DHCP?"
	moveMsgBox(220)
	Gui +OwnDialogs ;~ used to lock main gui until a selection is made
	MsgBox, 308, %WinName%, Set DHCP on this PC?
	IfMsgBox Yes
	{
		Gui, 1:+Disabled +AlwaysOnTop ;~ Disable main gui until the command completes
		GuiControl,, % hStatus, Setting local DHCP...
		RunWait, *RunAs PowerShell.exe -Command $adapter = Get-NetAdapter | ? {$_.Status -eq \""up\""} `; $interface = $adapter | Get-NetIPInterface -AddressFamily \""IPv4\"" `; If (($interface | Get-NetIPConfiguration).Ipv4DefaultGateway) { $interface | Remove-NetRoute -Confirm:$false } `; $interface | Set-NetIPInterface -DHCP Enabled `; $interface | Set-DnsClientServerAddress -ResetServerAddresses,,Hide
		
		;~ show a status bar progression over 1000ms
		;~ TODO: make this an accurate calculation for the DCHP routine
		iCount := 10
		Loop, %iCount% 
		{
			Position := 100/iCount * A_Index
			GuiControl,, LoopProgress, % Position
			Sleep, 100
		}
		;~ reenable main gui and reset status
		Gui, 1:-Disabled -AlwaysOnTop
		SetTimer, ClearProgress, -500
		SetTimer, ReadyStatus, -500
	}
	Return
}

ButtonCreateTunnel:
{
	;~ Routine when Create Tunnel button is clicked
	;~ Use Kitty to create a tunnel through a company JumpBox to the modem's 10dot IP address
	GuiControlGet, TenDot
	If (ValidIP(TenDot)) {
		WinName := "Create Tunnel?"
		moveMsgBox(220)
		Gui +OwnDialogs ;~ lock main gui until selection is made
		MsgBox, 308, %WinName%, Create tunnel to:`n     %TenDot%
		IfMsgBox Yes
		{		
			GuiControl,, % hStatus, Setting up HTTP tunnel...
			;~ select the NE1 jumpbox
			;~ TODO: Add this option into the settings menu
			jb := 1 
			Process, Close, %tunnelPID% ; Closes any existing instance
			fileName := A_WorkingDir "\KiTTY\KiTTY.exe"
			loginArg := "-ssh " JumpBox[jb].address " -P " JumpBox[jb].port " -l " JumpBox[jb].user " -pw " JumpBox[jb].pw
			tunnelArg := "-L 80:" TenDot ":80 -L 8080:" TenDot ":8080"
			target := fileName " " loginArg " " tunnelArg
			
			Run, %target%, %A_WorkingDir%\KiTTY, Minimize Hide, tunnelPID
			
			;~ show a status bar progression over 1000ms
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
	;~ Routine when Connect to Modem button is clicked
	;~ TODO: Add functionality for D3.1 modems/routers since they do not use the 10dot modem IP like AWG modems
	GuiControlGet, TenDot
	If (ValidIP(TenDot)) {
		jb := 1 ;~ Select the NE1 jumpbox | need to add this as an option in settings
		;~ Calculate position for MsgBox
		WinName := "Connect to Modem"
		moveMsgBox(220)
		Gui +OwnDialogs ;~ lock main gui until a slection is made
		MsgBox, 4, %WinName%, Connet to Jumpbox?
		IfMsgBox, Yes
		{
			;~ Connect and login to selcted Jumpbox over ssh
			fileName := A_WorkingDir "\KiTTY\KiTTY.exe"
			loginArg := "-ssh " JumpBox[jb].address " -P " JumpBox[jb].port " -l " JumpBox[jb].user " -pw " JumpBox[jb].pw
			target := fileName " " loginArg 
			Run, %target%, %A_WorkingDir%\KiTTY,, sshPID
			
			;~ send telnet command to Jumpbox which will connect to the modem
			WinName := "Telnet to Modem"
			moveMsgBox(220)
			Gui +OwnDialogs ;~ lock main gui until a slection is made
			;MsgBox,0,Telnet, When Ready: Press Ok to Telnet to modem.
			MsgBox,0,Telnet, Wait for Jump Box to Connect!`n`nClick OK to Telnet to %TenDot%`n`nUsername:`ttechnician`nPassword:`t(Copied to Clipboard)
			IfMsgBox, OK
			{
				IF ProcessExist(sshPID) 
				{
					sendText := "telnet " TenDot
					Clipboard := "AWG_Password"
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
	
	I_Icon = %A_WorkingDir%\include\images\Spectrum.ico
	IfExist, %I_Icon%
	Menu, Tray, Icon, %I_Icon%
	Menu, Tray, Tip, SMB ToolBox
	
	Gui, 9:+AlwaysOnTop -Caption
	Gui, 9:Margin, 10, 10
	Gui, 9:Add, Picture,, %A_WorkingDir%\include\images\splash_400x127.png
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
	
	If (FileExist("ping.txt")) {
		FileDelete, ping.txt
	}
}

OnUnload(ExitReason, ExitCode) {
	Global ; Assume-global mode
	
	Process, Close, %tunnelPID%
	Process, Close, %sshPID%
	WinClose, PingGUI.ahk
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
	;Gui, Font, S11 CDefault Bold, Arial
	;Gui, Add, Text, x%xCol_1% y%yTop_Row0_Text% w140 h20, Select Adapter:
	Gui, Font, S10 CDefault Normal, Arial
	;Gui, Add, DropDownList, x%xCol_1% y%yTop_Row0_Obj% w220 vAdaptersDDL gAdaptersDDL
	;Gui,  Add, Text, x445 y20 h35 0x11
	Gui, Add, Picture, x410 y20 w25 h25 Icon19 gIpInfo, C:\WINDOWS\SYSTEM32\SHELL32.dll
	Gui,  Add, Text, x445 y15 h35 0x11
	Gui, Add, Picture, x455 y20 w25 h25 Icon89 gNetInfo, C:\WINDOWS\SYSTEM32\SHELL32.dll
	Gui,  Add, Text, x490 y15 h35 0x11
	Gui, Add, Picture, x500 y20 w25 h25 Icon91 gChangeDefaults, C:\WINDOWS\SYSTEM32\SHELL32.dll
	
	; Top Row 1
	Gui, Font, S9 CDefault Normal, Arial
	Gui, Add, Text, x%xCol_1% y%yTop_Row1_Text% w80 h20, Gateway:
	Gui, Add, Text, x%xCol_2% yp w140 h20, Usable:
	Gui, Add, Text, x%xCol_3% yp w140 h20, SubnetMask:
	Gui, Font, S11 CDefault Normal, Courier
	Gui, Add, Edit, x%xCol_1% y%yTop_Row1_Obj% w160 HWNDhGateway gGW_Label vGateway +Center
	Gui, Add, Edit, x%xCol_2% yp w160 HWNDhUseable vUseable +Center
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
	;Gui, Add, Picture, x505 yp w20 h20 Icon89 gNetInfo, C:\WINDOWS\SYSTEM32\SHELL32.dll
	
	; Horizontal Line
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
	
	Gui, Show, w540, SMB ToolBox
	
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
	;GuiControlGet, AdaptersDDL
	GuiControl, -Disabled, ModemsDDL
	
	SetTimer, ClearProgress, -100
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
		arrSubnet := {0:24, 128:25, 192:26, 224:27, 240:28, 248:29, 252:30, 254:31, 255:32}
		Return arrSubnet[Octets4]
	}
	Return 0
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

moveMsgBox(width) {
	Global ; Assume-global mode
	;~ Function to move a MsgBox to center of main gui
	WinGetActiveStats, Title, W, H, X, Y
	WinX := X+(W/2)-(width/2)
	WinY := Y+100
	SetTimer, WinMoveMsgBox, 20
	Return
}

GuiSettings()
{
	Global ; Assume-global mode
	width := 490
	
	WinGetActiveStats, Title, W, H, X, Y
	WinX := X+(W/2)-(width/2)
	WinY := Y+100
	
	jumpBoxTXT =
(

Jumpbox data can be modified in the config file.


To add or change jumpboxes, use a text editor to open the file (SMBToolBox.ini)

)
	scriptsTXT =
(
Scripts are loaded from the \Scripts\ folder

Modem types are derived from the folder names.



Script's should utilize these key words:
[NETWORK] [GATEWAY] [USEABLE] [SUBNET] [DNS1] [DNS2] [RIPKEY] [HOST_NAME]


)
	aboutTXT =
(

Spectrum Business Class Tool Box


This tool is intented for orginizational use by Charter Communication's employee's.


If you are a Charter employee that does not understand this tool's purpose then it is not intended for you; delete and move on. 
Seriously, how did you even get this?
	

TODO: Make this tab sound more Professional.



Created by: Paul Launier
paul.launier@charter.com
)
	
	Gui, 1:+Disabled +AlwaysOnTop
	Gui, 2:+AlwaysOnTop +LastFound -Resize +HWNDh2Gui
	Gui, 2:+Owner
	Gui, 2:Margin, 10, 10
	
	Gui, 2:Font, S10 CDefault Normal, Arial	
	Gui, 2:Add, Tab3, x10 y10 w470 h350, Defaults||Jump Boxes|Scripts|About|
	
	Gui, 2:Tab, Defaults
	Gui, 2:Add, Text, w140 h20, RIP Key:
	Gui, 2:Add, Text, xp+155 yp w140 h20, DNS 1:
	Gui, 2:Add, Text, xp+155 yp w140 h20, DNS 2:
	Gui, 2:Font, S11 CDefault Normal, Courier
	Gui, 2:Add, Edit, x20 yp+17 w140 +Center, % Presets.rip
	Gui, 2:Add, Edit, xp+155 yp w140 +Center, % Presets.d1
	Gui, 2:Add, Edit, xp+155 yp w140 +Center, % Presets.d2
	
	;Tab Jump Boxes
	Gui, 2:Font, S10 CDefault Normal, Arial	
	Gui, 2:Tab, Jump Boxes
	Gui, 2:Add, Text, w450 h150 +Center vSettingsJB, % jumpBoxTXT
	
	; Tab Scripts
	Gui, 2:Tab, Scripts
	Gui, 2:Add, Text, w450 h150 +Center, % ScriptsTXT
	
	; Tab About
	Gui, 2:Tab, About
	Gui, 2:Add, Text, x20 y40 w450 h350 +Center, % aboutTXT
	
	Gui, 2:Tab, ;exit the tabs
	
	Gui, 2:Font, S11 CDefault Bold, Arial
	Gui, 2:Add, Button, x73 y380 w140 h25 +Center gSettingCancel, Cancel
	Gui, 2:Add, Button, x276 y380 w140 h25 +Center, Save Changes
	
	Gui, 2:Show, w%width% h410 x%WinX% y%WinY%, Default Settings
	
	Return
}

;===============================================================================
; Hotkeys
;===============================================================================

;===============================================================================
