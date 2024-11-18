using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.ComLayer
{
    public class Tunnel
    {
        #region Properties
        public int BacklogClients { get; set; } = 5000;
        public string Name { get; set; }
        public string Address { get; set; } = "";

        public int[] Ports { get; set; }

        public string SettingsName { get; set; } = "";

        #endregion

        #region Ctor
        public Tunnel()
        {

        }

        public Tunnel(string name)
        {
            Name = name;
        }
        #endregion
    }
}
