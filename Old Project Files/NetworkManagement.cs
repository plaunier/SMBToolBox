using System;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Diagnostics;

namespace BCToolBox
{
    public class NetworkManagement
    {
        public NetworkInterface ethernetInterface;
        public string gateway;
        public string useable;
        public string subnet;

        public NetworkManagement()
        {
            NetworkInterface[] interfaces = NetworkInterface.GetAllNetworkInterfaces();

            foreach (NetworkInterface adapter in interfaces)
            {
                if (adapter.NetworkInterfaceType == NetworkInterfaceType.Tunnel)
                {
                    continue;
                }

                if (adapter.NetworkInterfaceType == NetworkInterfaceType.Loopback)
                {
                    continue;
                }

                if (adapter.Description.IndexOf("VPN", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    adapter.Description.IndexOf("Cisco", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    adapter.Description.IndexOf("Wireless", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    continue;
                }

                ethernetInterface = adapter;
            }
            RefreshValues();
        }

        public void RefreshValues()
        {
            try
            {
                gateway = GetDefaultGateway().ToString();
                useable = GetDefaultIPv4Address().ToString();
                subnet = GetSubnet(useable).ToString();
            }
            catch
            {
                gateway = null;
                useable = null;
                subnet = null;
            }
        }

        //Get Gateway
        private IPAddress GetDefaultGateway()
        {
            if (ethernetInterface == null)
                return null;

            IPAddress result = null;
            
            try
            {
                var gateway = ethernetInterface.GetIPProperties().GatewayAddresses.FirstOrDefault(g => g.Address.AddressFamily.ToString() == "InterNetwork");
                return result = gateway.Address;
            }
            catch
            {
                return result;
            }
        }

        //Get Default IP Address
        private IPAddress GetDefaultIPv4Address()
        {
            if (ethernetInterface == null)
                return null;

            try
            {
                foreach (var address in ethernetInterface.GetIPProperties().UnicastAddresses)
                {
                    if (address.Address.AddressFamily != AddressFamily.InterNetwork)
                        continue;
                    if (address.IsTransient)
                        continue;
                    return address.Address;
                }
                return null;
            }
            catch
            {
                return null;
            }
        }

        // Get Subnet
        private IPAddress GetSubnet(string address)
        {
            if (ethernetInterface == null)
                return null;

            try
            {
                IPAddress subnet = new IPAddress(0);
                UnicastIPAddressInformationCollection UnicastIPInfoCol = ethernetInterface.GetIPProperties().UnicastAddresses;

                foreach (UnicastIPAddressInformation UnicatIPInfo in UnicastIPInfoCol)
                {
                    if (UnicatIPInfo.Address.ToString() == address)
                        subnet = UnicatIPInfo.IPv4Mask;
                }
                return subnet;
            }
            catch
            {
                return null;
            }
        }
    }//End Class
}//End Namespace
