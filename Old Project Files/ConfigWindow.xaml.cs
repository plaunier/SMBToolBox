using System;
using System.Windows;
using System.Windows.Controls;
using System.Configuration;
using System.Collections.Specialized;
using System.Diagnostics;
using System.Collections.Generic;
using System.Xml;
using System.Xml.XPath;

namespace BCToolBox
{    
    public partial class ConfigWindow : Window
    {
        bool _restartApp = false;
        ////////////////////////////////////////////////////////////////////////////////
        // Config Window
        ////////////////////////////////////////////////////////////////////////////////
        public ConfigWindow()
        {
            Owner = Application.Current.MainWindow;
            InitializeComponent();
            Closed += new EventHandler(ConfigWindow_Closed);
        }

        ////////////////////////////////////////////////////////////////////////////////
        // Functions
        ////////////////////////////////////////////////////////////////////////////////
        void ConfigWindow_Closed(object sender, EventArgs e)
        {
            if (_restartApp)
            {
                System.Diagnostics.Process.Start(Application.ResourceAssembly.Location);
                Application.Current.Shutdown();
            }
        }
        
        ////////////////////////////////////////////////////////////////////////////////
        // Event Handlers
        ////////////////////////////////////////////////////////////////////////////////
        private void OnConfigTabSelected(object sender, RoutedEventArgs e)
        {
            var tab = sender as TabItem;
            if (tab == tabDefaults)            
            {
                tboxConfigSubnet.Text = ConfigurationManager.AppSettings["Subnet"];
                tboxConfigDns1.Text = ConfigurationManager.AppSettings["Dns1"];
                tboxConfigDns2.Text = ConfigurationManager.AppSettings["Dns2"];
                tboxConfigRipkey.Text = ConfigurationManager.AppSettings["RipKey"];
                tboxConfigHostname.Text = ConfigurationManager.AppSettings["HostName"];
                return;
            }
            else if (tab == tabJumpBoxes)
            {
                string txt =    "\n" +
                                "Jumpbox data can be modified in the application config file.\n\n" +
                                "To add or change jumpboxes, use a text editor to open the file (BCToolBox.exe.config).\n\n" +
                                "Scroll down to the <JumpBoxes> section, Copy/Paste an existing Jumpbox line, then modify the values with new jumpbox info.\n\n" +
                                "Rinse and repeat for additional jumpboxes.\n\n";
                tboxConfigJumpboxes.Text = txt;
                return;
            }
            else if (tab == tabScripts)
            {
                string txt =    "Scripts are loaded from the \\Scripts\\ folder found in BCToolBox's application folder.\n\n" +
                                "Modem types are derived from the folder names.\n" +
                                "Therefore, proper folder structure must be maintained.\n\n" +
                                "To add a new modem, create a new folder in \\Scripts\\ using the following structure:\n" +
                                "\\Scripts\\ModemBrand\\ModelModel\\\n\n" +
                                "Newly created scripts must contain the Modem Model as the first part of it's file name.\n\n" +
                                "\"ModemModel ScriptName.txt\"\n" +
                                "\"36C Straight Static.txt\"\n\n" +
                                "ex: \"\\Scripts\\Ubee\\36C\\36C Straight Static.txt\"\n\n" +
                                "Script's should utilize these key words:\n" +
                                "[NETWORK] [GATEWAY] [USEABLE] [SUBNET] [DNS1] [DNS2] [RIPKEY] [HOST_NAME]";
                tboxConfigScripts.Text = txt;
                return;
            }
            else if (tab == tabAbout)
            {
                System.Reflection.Assembly assembly = System.Reflection.Assembly.GetExecutingAssembly();
                System.Reflection.AssemblyName assemblyName = assembly.GetName();
                Version version = assemblyName.Version;
                string txt =    "Spectrum Business Class Tool Box\n\n" +
                                "This tool is intented for orginizational use by Charter Communication's Business Class employee's.\n\n" +
                                "If you are a Charter employee that does not understand this tool's purpose then it is not intended for you; delete and move on. Seriously, how did you even get this?\n\n" +
                                "TODO: Make this tab sound more Professional.\n\n" +
                                "Created by: Paul Launier\n" +
                                "paul.launier@charter.com\n\n" +
                                "Version: " + version.ToString() + "\n\n" +
                                "";
                tboxAbout.Text = txt;
                return;
            }
        }

        ////////////////////////////////////////////////////////////////////////////////
        // Button Event Handlers
        ////////////////////////////////////////////////////////////////////////////////

        //Reload Defaults
        private void BtnConfigDefaultReload_Click(object sender, RoutedEventArgs e)
        {
            tboxConfigSubnet.Text = ConfigurationManager.AppSettings["Subnet"];
            tboxConfigDns1.Text = ConfigurationManager.AppSettings["Dns1"];
            tboxConfigDns2.Text = ConfigurationManager.AppSettings["Dns2"];
            tboxConfigRipkey.Text = ConfigurationManager.AppSettings["RipKey"];
            tboxConfigHostname.Text = ConfigurationManager.AppSettings["HostName"];
            return;
        }
    
        // Apply Changes
        private void BtnConfigDefaultApply_Click(object sender, RoutedEventArgs e)
        {
            string msgBoxTxt = "Save Changes to Default Values?";
            MessageBoxResult msgBoxResult = MessageBox.Show(msgBoxTxt, "Save Changes?", MessageBoxButton.OKCancel, MessageBoxImage.Question, MessageBoxResult.Cancel, MessageBoxOptions.None);
            if (msgBoxResult == MessageBoxResult.Cancel)
                return;

            Configuration config = ConfigurationManager.OpenExeConfiguration(ConfigurationUserLevel.None);

            //make changes
            config.AppSettings.Settings["Subnet"].Value = tboxConfigSubnet.Text;
            config.AppSettings.Settings["Dns1"].Value = tboxConfigDns1.Text;
            config.AppSettings.Settings["Dns2"].Value = tboxConfigDns2.Text;
            config.AppSettings.Settings["RipKey"].Value = tboxConfigRipkey.Text;
            config.AppSettings.Settings["HostName"].Value = tboxConfigHostname.Text;

            //save to apply changes
            config.Save(ConfigurationSaveMode.Modified);
            ConfigurationManager.RefreshSection("appSettings");

            // Restart Application
            _restartApp = true;
        }
    }//End ConfigWindow
}//End Namespace
