using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Runtime.Serialization;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Maba.VCT.CommServer.Monitor
{
    public partial class APIProtocolForm : Form
    {
        #region Properties

        //DIGI.APIProtocol.APIProtocol DigiApi = null;
        #endregion

        #region Ctor

        public APIProtocolForm()
        {
            InitializeComponent();
        }

        //public APIProtocolForm(DIGI.APIProtocol.APIProtocol digiApi) : this()
        //{
        //    DigiApi = digiApi;
        //    DigiApi.PacketReceived += DigiApi_PacketReceived;
        //    DigiApi.PacketSent += DigiApi_PacketSent;
        //}
        #endregion

        #region Events
        //private void DigiApi_PacketSent(object sender, DIGI.APIProtocol.PacketEventArgs e)
        //{
        //    this.Invoke(new Action(() =>
        //    {
        //        ListViewItem lvi = new ListViewItem(DateTime.UtcNow.ToString());
        //        lvi.ForeColor = Color.Blue;

        //        lvi.Tag = e.P;
        //        lvi.SubItems.Add(e.P.ToString());
        //        listViewDigiAPI.Items.Add(lvi);
        //    }));
        //}

        //private void DigiApi_PacketReceived(object sender, DIGI.APIProtocol.PacketEventArgs e)
        //{
        //    this.Invoke(new Action(() =>
        //    {
        //        ListViewItem lvi = new ListViewItem(DateTime.UtcNow.ToString());
        //        lvi.ForeColor = Color.Purple;
        //        lvi.Tag = e.P;
        //        lvi.SubItems.Add(e.P.ToString());
        //        listViewDigiAPI.Items.Add(lvi);
        //    }));
        //}

        #endregion

        #region Public Methods

        public void Init()
        {
            //DigiApi.LinkedNodes_SLIM.MyReadLock(list =>
            //{
            //    foreach (DIGI.APIProtocol.RemoteEndpoint item in list)
            //    {
            //        ListViewItem lvi = new ListViewItem(BytesToString(item.MAC));
            //        lvi.SubItems.Add(item.IsConnected.ToString());
            //        lvi.Tag = item;
            //        this.Invoke(new Action(() =>
            //        {
            //            listViewDigiNodes.Items.Add(lvi);
            //        }));
            //    }
            //});
        }

        #endregion
        
        #region Private Methods

        private string BytesToString(byte[] arr)
        {
            return string.Concat(arr.Select(a => a.ToString(" X2")));
        }


        #endregion

        #region Form Events
        private void buttonSendDigiAPIPAcket_Click(object sender, EventArgs e)
        {
            //DigiApi.SendPacket(new DIGI.APIProtocol.Packets.ATCommand(comboBoxDigiPackets.Text));
        }

        private void listView1_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (listViewDigiNodes.SelectedItems.Count == 0)
            {
                propertyGridSingleNode.Enabled = false;
                propertyGridSingleNode.SelectedObject = null;
            }
            else
            {
                propertyGridSingleNode.SelectedObject = listViewDigiNodes.SelectedItems[0].Tag;
                propertyGridSingleNode.Enabled = true;
            }
        }

        #endregion
    }
}
