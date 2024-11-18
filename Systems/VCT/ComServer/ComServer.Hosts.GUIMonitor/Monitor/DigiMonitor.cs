using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Maba.VCT.CommServer.Monitor
{
    public partial class DigiMonitor : Form
    {
        #region Proprties

        public Core.MultiBLCommServer ComServer { get; private set; }

        #endregion

        #region Ctor

        public DigiMonitor()
        {
            InitializeComponent();
        }

        //public DigiMonitor(Core.MultiBLCommServer _comServer) : this()
        //{
        //    ComServer = _comServer;
        //    ComServer.NewDigiGatewayConnected += ComServer_NewDigiGatewayConnected;
        //}

        //private void ComServer_NewDigiGatewayConnected(object o, DIGI.APIProtocol.Events.NewGateWayConnectionEventArgs e)
        //{
        //    ListViewItem lvi = new ListViewItem(e.Gateway.InternalComLayer.ToString());
        //    lvi.SubItems.Add(e.Gateway.IsConnected.ToString());
        //    lvi.Tag = e.Gateway;
        //    this.Invoke(new Action(() =>
        //    {
        //        listViewDigiBare.Items.Add(lvi);
        //    }));
        //}


        #endregion
        
        #region Form Events

        private void listViewDigiBare_SelectedIndexChanged(object sender, EventArgs e)
        {
            //if (listViewDigiBare.SelectedItems.Count > 0)
            //{
            //    var api = listViewDigiBare.Tag as DIGI.APIProtocol.APIProtocol;
            //    APIProtocolForm apf = new APIProtocolForm(api);
            //    apf.Init();
            //    apf.Show();
            //    this.Hide();
            //}
        }

        #endregion
    }
}
