using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BCToolBox
{
    public class JumpBoxConfig : ConfigurationSection
    {
        public const string SectionName = "JumpBoxConfig";

        private const string CollectionName = "JumpBoxes";

        //public static JumpBoxConfig GetConfig()
        //{
        //    return (JumpBoxConfig)System.Configuration.ConfigurationManager.GetSection("JumpBoxConfig") ?? new JumpBoxConfig();
        //}

        [ConfigurationProperty(CollectionName)]
        [ConfigurationCollection(typeof(JumpBoxCollection), AddItemName = "add")]
        public JumpBoxCollection JumpBoxes { get { return (JumpBoxCollection)base[CollectionName]; } }
    }

    public class JumpBoxCollection : ConfigurationElementCollection
    {
        protected override ConfigurationElement CreateNewElement()
        {
            return new JumpBoxElement();
        }

        protected override object GetElementKey(ConfigurationElement element)
        {
            return ((JumpBoxElement)element).Name;
        }
    }

    public class JumpBoxElement : ConfigurationElement
    {
        [ConfigurationProperty("name", IsRequired = true)]
        public string Name
        {
            get { return (string)this["name"]; }
            set { this["name"] = value; }
        }

        [ConfigurationProperty("address", IsRequired = true)]
        public string Address
        {
            get { return (string)this["address"]; }
            set { this["address"] = value; }
        }

        [ConfigurationProperty("port", IsRequired = true)]
        public int Port
        {
            get { return (int)this["port"]; }
            set { this["port"] = value; }
        }

        [ConfigurationProperty("user", IsRequired = true)]
        public string User
        {
            get { return (string)this["user"]; }
            set { this["user"] = value; }
        }

        [ConfigurationProperty("password", IsRequired = true)]
        public string Password
        {
            get { return (string)this["password"]; }
            set { this["password"] = value; }
        }

        [ConfigurationProperty("default", IsRequired = false)]
        public bool Default
        {
            get { return (bool)this["default"]; }
            set { this["default"] = value; }
        }
    }
}
