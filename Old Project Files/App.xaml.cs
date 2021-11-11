using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Threading;


namespace BCToolBox
{
    /// <summary>
    /// Interaction logic for App.xaml
    /// </summary>
    public partial class App : Application
    {
        App()
        {
            Thread.Sleep(2000);
        }

        private void Application_Exit(object sender, ExitEventArgs e)
        {
            try { GlobalProcess.pTunnel.Kill(); }
            catch { }

            try { GlobalProcess.pKitty.Kill(); }
            catch { }
        }
    }
}
