using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net;
using System.Timers;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Configuration;
using System.IO;
using System.Runtime.InteropServices;
using WindowsInput;
using WindowsInput.Native;
using System.Threading;
using System.Windows.Threading;
using System.Xml;

namespace BCToolBox
{
    public static class GlobalProcess
    {
        public static Process pTunnel = new Process();
        public static Process pKitty = new Process();
    }

    public partial class MainWindow : Window
    {
        ////////////////////////////////////////////////////////////////////////////////
        // MainWindow Globals
        ////////////////////////////////////////////////////////////////////////////////
        bool _changingGW;     // Used for Gateway Text Change Event
        bool _changingTD;     // Used for Ten Dot Text Change Event
        bool _changingScript;  // Used for Script Change Event
        private static System.Timers.Timer errorLblTimer;   // Error Message Timer

        CurrentValues currentValues = new CurrentValues();

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [System.Runtime.InteropServices.DllImportAttribute("user32.dll", EntryPoint = "BlockInput")]
        [return: System.Runtime.InteropServices.MarshalAsAttribute(System.Runtime.InteropServices.UnmanagedType.Bool)]
        public static extern bool BlockInput([System.Runtime.InteropServices.MarshalAsAttribute(System.Runtime.InteropServices.UnmanagedType.Bool)] bool fBlockIt);

        ////////////////////////////////////////////////////////////////////////////////
        // Main
        ////////////////////////////////////////////////////////////////////////////////
        public MainWindow()
        {
            InitializeComponent();

            // Timer for showing errors
            errorLblTimer = new System.Timers.Timer(4000);
            errorLblTimer.Elapsed += OnErrorLblTimerEvent;

            // Load Subnet Value from Config
            tboxSubnet.Text = ConfigurationManager.AppSettings["Subnet"];
 
            // Populate JumpBox ComboBox
            for (int i = 0; i < currentValues.jumpBoxList.Count; i++)
            {
                cbJumpBox.Items.Add(currentValues.jumpBoxList[i].Name);
                if (currentValues.jumpBoxList[i].Default == true)
                {
                    cbJumpBox.SelectedIndex = i;
                }
            }

            // Populate Modem Combobox
            for(int i=0; i < currentValues.modemList.Count; i++)
            {
                cbModem.Items.Add(currentValues.modemList[i].modemBrand + " - " + currentValues.modemList[i].modemModel);
            }

        }//End Main

        ////////////////////////////////////////////////////////////////////////////////
        // Functions
        ////////////////////////////////////////////////////////////////////////////////

        //IsValidIPv4
        private static bool IsValidIPv4(string ipString)
        {
            if (String.IsNullOrWhiteSpace(ipString))
            {
                return false;
            }

            string[] splitValues = ipString.Split('.');
            if (splitValues.Length != 4)
            {
                return false;
            }

            return splitValues.All(r => byte.TryParse(r, out byte tempForParsing));
        }

        // Refresh Script TextBox
        private void RefreshScript()
        {
            string scriptPath = currentValues.ScriptPath() + "\\" + currentValues.currentModem.scripts[cbScript.SelectedIndex];
            string newLine;

            tboxScript.Clear();

            var lines = File.ReadAllLines(scriptPath);
            foreach (string line in lines)
            {
                newLine = line;

                if (IsValidIPv4(tboxGateway.Text) && !String.IsNullOrEmpty(ConfigurationManager.AppSettings["ScriptReplaceValue_Gateway"]))
                    newLine = newLine.Replace(ConfigurationManager.AppSettings["ScriptReplaceValue_Gateway"], tboxGateway.Text);
                if (IsValidIPv4(tboxUseable.Text) && !String.IsNullOrEmpty(ConfigurationManager.AppSettings["ScriptReplaceValue_Useable"]))
                    newLine = newLine.Replace(ConfigurationManager.AppSettings["ScriptReplaceValue_Useable"], tboxUseable.Text);
                if (IsValidIPv4(currentValues.networkIP) && !String.IsNullOrEmpty(ConfigurationManager.AppSettings["ScriptReplaceValue_Network"]))
                    newLine = newLine.Replace(ConfigurationManager.AppSettings["ScriptReplaceValue_Network"], currentValues.networkIP);
                if (IsValidIPv4(tboxSubnet.Text) && !String.IsNullOrEmpty(ConfigurationManager.AppSettings["ScriptReplaceValue_Subnet"]))
                    newLine = newLine.Replace(ConfigurationManager.AppSettings["ScriptReplaceValue_Subnet"], tboxSubnet.Text);
                if (!String.IsNullOrEmpty(ConfigurationManager.AppSettings["ScriptReplaceValue_Dns1"]))
                    newLine = newLine.Replace(ConfigurationManager.AppSettings["ScriptReplaceValue_Dns1"], currentValues.dns[0]);
                if (!String.IsNullOrEmpty(ConfigurationManager.AppSettings["ScriptReplaceValue_Dns2"]))
                    newLine = newLine.Replace(ConfigurationManager.AppSettings["ScriptReplaceValue_Dns2"], currentValues.dns[1]);
                if (!String.IsNullOrEmpty(ConfigurationManager.AppSettings["ScriptReplaceValue_RipKey"]) && !String.IsNullOrEmpty(currentValues.ripKey))
                    newLine = newLine.Replace(ConfigurationManager.AppSettings["ScriptReplaceValue_RipKey"], currentValues.ripKey);
                if (!String.IsNullOrEmpty(ConfigurationManager.AppSettings["ScriptReplaceValue_HostName"]) && !String.IsNullOrEmpty(currentValues.hostName))
                    newLine = newLine.Replace(ConfigurationManager.AppSettings["ScriptReplaceValue_HostName"], currentValues.hostName);

                tboxScript.Text += newLine + Environment.NewLine;
            }
        }

        //ChangeIPAddr
        private string ChangeIPAddr(string ipAddr , int step)
        {
            IPAddress oIP = IPAddress.Parse(ipAddr);
            byte[] byteIP = oIP.GetAddressBytes();

            uint ip;
            if ( ((uint)byteIP[3] == 0xFF && step >= 0 ) ||
                 ((uint)byteIP[3] == 0x00 && step <= 0)   )
            {
                ip = ((uint)byteIP[3]) << 24;
            }
            else
            {
                if (step > 0)
                    ip = ((uint)byteIP[3] + 1 ) << 24;
                else
                    ip = ((uint)byteIP[3] - 1) << 24;
            }
            ip += (uint)byteIP[2] << 16;
            ip += (uint)byteIP[1] << 8;
            ip += (uint)byteIP[0];

            return new IPAddress(ip).ToString();
        }

        // Display Error Messsage
        private void DisplayErrorMsg(string msg , TextBlock tb )
        {
            errorLblTimer.Stop();

            tb.Foreground = new SolidColorBrush(Colors.Red);
            tb.Text = msg;
            errorLblTimer.Start();
        }

        // SetIP
        private void SetStaticIP(string ipAddress, string subnetMask, string gateway, string[] nameServers)
        {
            if (!IsValidIPv4(tboxGateway.Text))
            {
                DisplayErrorMsg("Gateway is Not a Valid IP Address", tblInfoErrorText);
                errorLblTimer.Start();
                return;
            }
            if (!IsValidIPv4(tboxUseable.Text))
            {
                DisplayErrorMsg("Useable is Not a Valid IP Address", tblInfoErrorText);
                errorLblTimer.Start();
                return;
            }
            if (!IsValidIPv4(tboxSubnet.Text))
            {
                DisplayErrorMsg("Subnet is Not a Valid IP Address", tblInfoErrorText);
                errorLblTimer.Start();
                return;
            }
            if (!IsValidIPv4(currentValues.dns[0]) || !IsValidIPv4(currentValues.dns[1]))
            {
                DisplayErrorMsg("DNS is Not a Valid IP Address", tblInfoErrorText);
                errorLblTimer.Start();
                return;
            }

            MessageBoxResult result = MessageBox.Show("Set your PC to a Static IP?", "Set Static", MessageBoxButton.OKCancel, MessageBoxImage.Question,
                            MessageBoxResult.Cancel, MessageBoxOptions.None);
            if (result == MessageBoxResult.Cancel)
                return;

            using (new WaitCursor())
            {
                string ethName = currentValues.nicManagement.ethernetInterface.Name;
                string args = "/c netsh interface ip set address \"" + ethName + "\" static " + ipAddress + " " + subnetMask + " " + gateway + " & netsh interface ip set dns \"" + ethName + "\" static " + nameServers[0] + " & netsh interface ip add dns \"" + ethName + "\" addr=" + nameServers[1] + " index=2";

                tblInfoErrorText.Foreground = new SolidColorBrush(Colors.Black);
                tblInfoErrorText.Text = "Setting Static IP, Just a Moment...";
                errorLblTimer.Start();

                Process cmd = new Process();
                ProcessStartInfo psi = new ProcessStartInfo()
                {
                    FileName = "cmd.exe",
                    Arguments = args,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    CreateNoWindow = true,
                    Verb = "runas",
                    UseShellExecute = true,
                };
 
                cmd.StartInfo = psi;
                try
                {
                    cmd.Start();
                    cmd.WaitForExit();
                    cmd.Close();
                }
                catch
                {
                    DisplayErrorMsg("Error! Static was NOT set.", tblInfoErrorText);
                    return;
                }
            }
        }

        // Set DHCP
        private void SetDHCP()
        {
            using (new WaitCursor())
            {
                string ethName = currentValues.nicManagement.ethernetInterface.Name;
                string args = "/c netsh int ip reset & netsh interface ip set address \"" + ethName + "\" dhcp & netsh interface ip set dns \"" + ethName + "\" dhcp";
                string renew = "ipconfig /renew \"" + ethName + "\"";

                Process cmd = new Process();
                ProcessStartInfo psi = new ProcessStartInfo()
                {
                    FileName = "cmd.exe",
                    Arguments = args,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    CreateNoWindow = true,
                    Verb = "runas",
                    UseShellExecute = true,
                };

                tblInfoErrorText.Foreground = new SolidColorBrush(Colors.Black);
                tblInfoErrorText.Text = "Setting DHCP, Just a Moment...";
                errorLblTimer.Start();
                cmd.StartInfo = psi;
                try
                {
                    cmd.Start();
                    cmd.WaitForExit();
                }
                catch
                {
                    DisplayErrorMsg("Error! IP Settings NOT changed.", tblInfoErrorText);
                    return;
                }

                Thread.Sleep(1500);
                cmd.Refresh();
                psi.FileName = "cmd.exe";
                psi.Arguments = "/C ipconfig /renew";
                psi.Verb = "";

                try
                {
                    cmd.Start();
                    cmd.WaitForExit();
                    cmd.Close();
                }
                catch
                {
                    DisplayErrorMsg("Error! IP Settings NOT changed.", tblInfoErrorText);
                    return;
                }
            }
        }

        // Error Timer Event Handler
        private void OnErrorLblTimerEvent(Object source, ElapsedEventArgs e)
        {
            Application.Current.Dispatcher.Invoke(new Action(() =>
            {
                tblInfoErrorText.Text = "";
                tblScriptingErrorText.Text = "";
            }));
            errorLblTimer.Stop();
            return;
        }

        ////////////////////////////////////////////////////////////////////////////////
        // TextBox Events
        ////////////////////////////////////////////////////////////////////////////////

        // Gateway TextChanged Event
        private void TboxGateway_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (_changingGW)
                return;
            _changingGW = true;

            TextBox tb = sender as TextBox;
            int tbIndex = tb.CaretIndex;

            string txt = tb.Text;
            while (txt.Contains(" "))
            {
                txt = txt.Replace(" ", string.Empty);
                tbIndex--;
            }
            tb.Text = txt;
            tb.CaretIndex = tbIndex;
            _changingGW = false;

            if (IsValidIPv4(tb.Text))
            {
                tboxUseable.Text = ChangeIPAddr(tb.Text, 1);
                currentValues.networkIP = ChangeIPAddr(tb.Text, -1);
            }
        }

        // Gateway LostFocus Event
        private void TboxGateway_LostFocus(object sender, RoutedEventArgs e)
        {
            TextBox textBox = sender as TextBox;
            textBox.Text = textBox.Text.Trim();
            if (!IsValidIPv4(textBox.Text))
            {
                DisplayErrorMsg("Gateway is Not a Valid IP Address", tblInfoErrorText);
                tboxUseable.Text = "";
                currentValues.networkIP = "";
            }
        }

        // Ten Dot Text Changed Event
        private void TboxTenDot_TextChanged(object sender, TextChangedEventArgs e)
        {
            if (_changingTD)
                return;
            _changingTD = true;

            TextBox tb = sender as TextBox;
            int tbIndex = tb.CaretIndex;

            string txt = tb.Text;
            while (txt.Contains(" "))
            {
                txt = txt.Replace(" ", string.Empty);
                tbIndex--;
            }
            tb.Text = txt;
            tb.CaretIndex = tbIndex;
            _changingTD = false;
        }

        // Ten Dot Lost Focus Event
        private void TboxTenDot_LostFocus(object sender, RoutedEventArgs e)
        {
            TextBox textBox = sender as TextBox;
            textBox.Text = textBox.Text.Trim();

            if (!IsValidIPv4(textBox.Text))
            {
                DisplayErrorMsg("Ten Dot is Not a Valid IP Address", tblInfoErrorText);
                return;
            }

            string[] splitValues = textBox.Text.Split('.');
            Int32.TryParse(splitValues[0], out int x);
            if (x != 10)
            {
                DisplayErrorMsg("Ten Dot is Not a Valid IP Address", tblInfoErrorText);
            }
        }

        // Useable Double Click Event
        private void TboxUseable_MouseDoubleClick(object sender, MouseButtonEventArgs e)
        {
            TextBox tb = sender as TextBox;
            tb.IsReadOnly = false;
            tb.Background = null;
            string txt = tb.Text;
            int lastDelim = txt.LastIndexOf('.') + 1;
            tb.Select(lastDelim, txt.Length);
        }
        
        // Subnet Double Click Event
        private void TboxSubnet_MouseDoubleClick(object sender, MouseButtonEventArgs e)
        {
            TextBox tb = sender as TextBox;
            tb.IsReadOnly = false;
            tb.Background = null;
            tb.Select(12, 14);
        }

        ////////////////////////////////////////////////////////////////////////////////
        // Button Events
        ////////////////////////////////////////////////////////////////////////////////

        // Change Settings
        private void BtnSettings_Click(object sender, RoutedEventArgs e)
        {
            ConfigWindow cw = new ConfigWindow();
            cw.Show();
            //cw.Topmost = true;          
        }

        // Open Network Settings
        private void tbNetworkSetting_PreviewMouseDown(object sender, MouseButtonEventArgs e)
        {
            Process.Start("ncpa.cpl");
        }

        // Paste Gateway
        private void BtnPasteGateway_Click(object sender, RoutedEventArgs e)
        {
            string clipStr = Clipboard.GetText().Trim();
            if (IsValidIPv4(clipStr))
                tboxGateway.Text = clipStr.Substring(0, Math.Min(clipStr.Length, 15));
            else
                DisplayErrorMsg("Clipboard is Not a Valid IP Address", tblInfoErrorText);
        }

        // Paste Ten Dot
        private void BtnPasteTenDot_Click(object sender, RoutedEventArgs e)
        {
            string clipStr = Clipboard.GetText().Trim();
            if (IsValidIPv4(clipStr))
                tboxTenDot.Text = clipStr.Substring(0, Math.Min(clipStr.Length, 15));
            else
                DisplayErrorMsg("Clipboard is Not a Valid IP Address", tblInfoErrorText);
        }

        // Reload Script
        private void BtnReloadScript_Click(object sender, RoutedEventArgs e)
        {
            RefreshScript();
        }

        // Copy Script to Clipboard
        private void BtnCopyScript_Click(object sender, RoutedEventArgs e)
        {
            Clipboard.Clear();
            Clipboard.SetText(tboxScript.Text);
        }

        // Ping Gateway
        private void BtnPingGateway_Click(object sender, RoutedEventArgs e)
        {
            if (IsValidIPv4(tboxGateway.Text))
            {
                try
                {
                    Process.Start("CMD.lnk", "/C ping /t " + tboxGateway.Text);
                }
                catch
                {
                    Process.Start("CMD.exe", "/C ping /t " + tboxGateway.Text);
                }
            }
            else
                DisplayErrorMsg("Gateway is Not a Valid IP Address", tblInfoErrorText);
        }

        // Create Tunnel Button Event
        private void BtnTunnel_Click(object sender, RoutedEventArgs e)
        {
            if (!IsValidIPv4(tboxTenDot.Text))
            {
                DisplayErrorMsg("TenDot is Not a Valid IP Address", tblScriptingErrorText);
                return;
            }

            string fileName = currentValues.appRootDir + "KiTTY\\KiTTY.exe";
            string loginArg = "-ssh " + currentValues.currentJumpBox.Address + " -P " + currentValues.currentJumpBox.Port + " -l " + currentValues.currentJumpBox.User + " -pw " + currentValues.currentJumpBox.Password;
            string tunnelArg = "-L 80:" + tboxTenDot.Text + ":80 -L 8080:" + tboxTenDot.Text + ":8080";

            GlobalProcess.pTunnel.Refresh();
            bool pExists = true;

            try { Process.GetProcessById(GlobalProcess.pTunnel.Id); }
            catch (InvalidOperationException) { pExists = false; }
            catch (ArgumentException) { pExists = false; }

            if (pExists) GlobalProcess.pTunnel.Kill();

            GlobalProcess.pKitty = new Process();

            ProcessStartInfo psi = new ProcessStartInfo()
            {
                FileName = fileName,
                Arguments = loginArg + " " + tunnelArg + " -send-to-tray",
                WindowStyle = ProcessWindowStyle.Minimized,
                UseShellExecute = false,
            };

            GlobalProcess.pTunnel.StartInfo = psi;
            GlobalProcess.pTunnel.Start();

            currentValues.currentModem.LoginInfo(out string user, out string pw, out string localhost);

            MessageBoxResult result = MessageBox.Show("Open LocalHost in Web Browser?" + "\n\n" +
                            "Username: " + user + "\n" + "Password: (Copied to Clipboard)", "Open Web Browser", MessageBoxButton.OKCancel, MessageBoxImage.Question,
                            MessageBoxResult.Cancel, MessageBoxOptions.None);
            if (result == MessageBoxResult.OK)
            {
                Clipboard.Clear();
                Clipboard.SetText(pw);
                Process.Start(localhost);
            }
        }

        // Connect to JumpBox Button Event
        private void BtnConnectSsh_Click(object sender, RoutedEventArgs e)
        {
            MessageBoxResult msgBoxResult;
            string msgBoxTxt = "";
            bool _noTelnet = false;

            if (currentValues.currentModem == null)
            {
                msgBoxTxt = "No modem selected.\n";
                _noTelnet = true;
            }
            if (!IsValidIPv4(tboxTenDot.Text))
            {
                msgBoxTxt += "Ten Dot is not valid.\n";
                _noTelnet = true;
            }

            if (_noTelnet)
            {
                msgBoxResult = MessageBox.Show(msgBoxTxt + "\nContinue to Jumpbox Anyways?", "Telnet Connection Not Possible!", MessageBoxButton.OKCancel, MessageBoxImage.Warning, MessageBoxResult.Cancel, MessageBoxOptions.None);
                if (msgBoxResult == MessageBoxResult.Cancel)
                    return;
            }

            string fileName = currentValues.appRootDir + "KiTTY\\KiTTY.exe";
            string loginArg = "-ssh " + currentValues.currentJumpBox.Address + " -P " + currentValues.currentJumpBox.Port + " -l " + currentValues.currentJumpBox.User + " -pw " + currentValues.currentJumpBox.Password;

            GlobalProcess.pKitty.Refresh();

            bool pExists = true;

            try { Process.GetProcessById(GlobalProcess.pKitty.Id); }
            catch (InvalidOperationException) { pExists = false; } 
            catch (ArgumentException) { pExists = false; }
            
            if (pExists) GlobalProcess.pKitty.Kill();

            GlobalProcess.pKitty = new Process();

            ProcessStartInfo psi = new ProcessStartInfo()
            {
                FileName = fileName,
                Arguments = loginArg,
                UseShellExecute = false
            };

            GlobalProcess.pKitty.StartInfo = psi;
            try { GlobalProcess.pKitty.Start(); } catch { return; }
            Thread.Sleep(500);

            if (!_noTelnet)
            {
                try { Process.GetProcessById(GlobalProcess.pKitty.Id); } catch { return; }
                Activate();
                currentValues.currentModem.LoginInfo(out string user, out string pw, out string localhost);
                msgBoxResult = MessageBox.Show("Wait for Jump Box to Connect!\n\n Click OK to Telnet to " + tboxTenDot.Text + "\n\n" + "Username: " + user + "\n" +
                                "Password: (Copied to Clipboard)", "Telnet to Customer's Modem", MessageBoxButton.OKCancel, MessageBoxImage.Information,
                                MessageBoxResult.Cancel, MessageBoxOptions.None);
                if (msgBoxResult == MessageBoxResult.OK)
                {
                    Clipboard.Clear();
                    Clipboard.SetText(pw);

                    InputSimulator sim = new InputSimulator();
                    BlockInput(true);

                    SetForegroundWindow(GlobalProcess.pKitty.MainWindowHandle);
                    sim.Keyboard.Sleep(300);
                    sim.Keyboard.TextEntry("telnet " + tboxTenDot.Text);
                    sim.Keyboard.KeyPress(VirtualKeyCode.RETURN);
                    BlockInput(false);
                }
            }
        }

        // Set Static IP
        private void BtnStatic_Click(object sender, RoutedEventArgs e)
        {
            SetStaticIP(tboxUseable.Text, tboxSubnet.Text, tboxGateway.Text, currentValues.dns);
        }

        // Set DHCP
        private void BtnDHCP_Click(object sender, RoutedEventArgs e)
        {
            SetDHCP();
        }

        ////////////////////////////////////////////////////////////////////////////////
        // ComboBox Events
        ////////////////////////////////////////////////////////////////////////////////

        // Jump Box Selection Changed Event
        private void CbJumpBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            ComboBox cb = sender as ComboBox;
            currentValues.currentJumpBox =  currentValues.jumpBoxList[cb.SelectedIndex];
        }

        // Modem Selection Changed Event
        private void CbModem_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            ComboBox cb = sender as ComboBox;
            currentValues.currentModem = currentValues.modemList[cb.SelectedIndex];

            _changingScript = true;
            cbScript.Items.Clear();
            tboxScript.Clear();
            for(int i=0; i < currentValues.currentModem.scripts.Count; i++)
            {
                string name = currentValues.currentModem.scripts[i].Substring(currentValues.currentModem.scripts[i].IndexOf(" ")+1).Trim() ;
                name = name.Substring(0, name.IndexOf(".txt"));
                cbScript.Items.Add(name);
            }
            cbScript.IsEnabled = true;
            btnTunnel.IsEnabled = true;
            _changingScript = false;
            btnReloadScript.IsEnabled = false;
            btnCopyScript.IsEnabled = false;
        }

        // Script Selection Changed Event
        private void CbScript_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (_changingScript)
                return;
            RefreshScript();          

            btnReloadScript.IsEnabled = true;
            btnCopyScript.IsEnabled = true;
        }

    }// End Class MainWindow

    ////////////////////////////////////////////////////////////////////////////////
    // Helper Classes
    ////////////////////////////////////////////////////////////////////////////////
    public class CurrentValues
    {
        public JumpBoxElement currentJumpBox;
        public ModemScripts currentModem;
        public List<JumpBoxElement> jumpBoxList = new List<JumpBoxElement>();
        public List<ModemScripts> modemList = new List<ModemScripts>();
        public NetworkManagement nicManagement = new NetworkManagement();
        public string appRootDir = System.AppDomain.CurrentDomain.BaseDirectory;        
        public string[] dns = new string[2];
        public string networkIP;
        public string ripKey;
        public string hostName;

        public CurrentValues()
        {
            // Get Jumpboxes from config File
            if (ConfigurationManager.GetSection(JumpBoxConfig.SectionName) is JumpBoxConfig jumpBoxConfig)
            {
                foreach (JumpBoxElement jumpBox in jumpBoxConfig.JumpBoxes)
                {
                    jumpBoxList.Add(jumpBox);
                }
            }

            // Initial Values from Config
            dns[0] = ConfigurationManager.AppSettings["Dns1"];
            dns[1] = ConfigurationManager.AppSettings["Dns2"];
            ripKey = ConfigurationManager.AppSettings["RipKey"];
            hostName = ConfigurationManager.AppSettings["HostName"];
            networkIP = null;

            // Scripts
            try
            {
                foreach (var brand in Directory.GetDirectories(appRootDir + "Scripts\\"))
                {
                    var brandDir = new DirectoryInfo(brand);

                    foreach (var type in Directory.GetDirectories(brandDir.ToString()))
                    {
                        var typeDir = new DirectoryInfo(type);
                        ModemScripts temp = new ModemScripts
                        {
                            modemBrand = brandDir.Name,
                            modemModel = typeDir.Name
                        };

                        string[] fileArray = Directory.GetFiles(typeDir.ToString());
                        for (int i = 0; i < fileArray.Length; i++)
                        {
                            temp.scripts.Add(System.IO.Path.GetFileName(fileArray[i]));
                        }
                        modemList.Add(temp);
                    }
                }
            }
            catch
            {

            }
        }

        // Return full path to Current Script
        public string ScriptPath()
        {
            try
            {
                return appRootDir + "Scripts\\" + currentModem.modemBrand + "\\" + currentModem.modemModel;
            }
            catch
            {
                return null;
            }
        }
    }//End CurrentValue Class
    ////////////////////////////////////////////////////////////////////////////////

    // Modem Script Class
    public class ModemScripts
    {
        public string modemBrand;
        public string modemModel;
        public string localHost;
        public List<string> scripts = new List<string>();
        private string appRootDir = System.AppDomain.CurrentDomain.BaseDirectory;

        public void LoginInfo(out string user, out string password, out string localhost)
        {
            string scriptPath = appRootDir + "Scripts\\" + modemBrand + "\\" + modemModel;
            user = "";
            password = "";
            localhost = "http://127.0.0.1";

            for (int i=0; i<scripts.Count; i++)
            {
                if(scripts[i].IndexOf("login info", StringComparison.OrdinalIgnoreCase) != -1)
                {
                    scriptPath += "\\" + scripts[i];
                    var lines = File.ReadAllLines(scriptPath);
                    foreach (string line in lines)
                    {
                        if (line.IndexOf("username", StringComparison.OrdinalIgnoreCase) != -1)
                            user = line.Substring(line.IndexOf(":") + 1).Trim();
                        else if (line.IndexOf("password", StringComparison.OrdinalIgnoreCase) != -1)
                            password = line.Substring(line.IndexOf(":") + 1).Trim();
                        else if (line.IndexOf("localhost", StringComparison.OrdinalIgnoreCase) != -1)
                            localhost = line.Substring(line.IndexOf(":") + 1).Trim();
                    }
                    return;
                }
            }
            return;
        }
    }//End ModemScripts Class
    ////////////////////////////////////////////////////////////////////////////////

    // Wait Cursor
    public class WaitCursor : IDisposable
    {
        private Cursor _previousCursor;

        public WaitCursor()
        {
            _previousCursor = Mouse.OverrideCursor;

            Mouse.OverrideCursor = Cursors.Wait;
        }

        #region IDisposable Members

        public void Dispose()
        {
            Mouse.OverrideCursor = _previousCursor;
        }

        #endregion
    }//END Wait Cursor
    ////////////////////////////////////////////////////////////////////////////////
}//End Namespace
