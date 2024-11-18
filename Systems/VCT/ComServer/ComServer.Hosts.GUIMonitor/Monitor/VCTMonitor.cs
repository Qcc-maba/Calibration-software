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
    public partial class VCTMonitor : Form
    {
        #region Proprties

        public VCT.Core.ServerCore CoreServer { get; private set; }

        private List<DeviceRecord<VCT.Core.Device.DeviceHost>> _identifiedConnection = new List<DeviceRecord<VCT.Core.Device.DeviceHost>>();
        private List<DeviceRecord<VCT.Core.Device.DeviceHost>> _bareConnection = new List<DeviceRecord<VCT.Core.Device.DeviceHost>>();

        private System.Collections.Concurrent.ConcurrentQueue<DeviceRecord<VCT.Core.Device.DeviceHost>> Identified_ItemsToAdd = null;
        private System.Collections.Concurrent.ConcurrentQueue<DeviceRecord<VCT.Core.Device.DeviceHost>> Bare_ItemsToAdd = null;

        #endregion

        #region Ctor

        public VCTMonitor()
        {
            InitializeComponent();

            Identified_ItemsToAdd = new System.Collections.Concurrent.ConcurrentQueue<DeviceRecord<VCT.Core.Device.DeviceHost>>();
            Bare_ItemsToAdd = new System.Collections.Concurrent.ConcurrentQueue<DeviceRecord<VCT.Core.Device.DeviceHost>>();
        }

        public VCTMonitor(VCT.Core.ServerCore _CoreServer) : this()
        {
            CoreServer = _CoreServer;
            CoreServer.MainEventsBus.DeviceConnnection += MainEventsBus_DeviceConnnection;
            CoreServer.MainEventsBus.DeviceUnIdentifyConnnection += MainEventsBus_DeviceUnIdentifyConnnection;
        }

        #endregion

        #region Timer

        private int timers = 0;

        private void timer_lists_Tick(object sender, EventArgs e)
        {
            #region identified connections

            bool updateIdentifiedList = false;
            var identifiedToAdd = new List<ListViewItem>();

            DeviceRecord<VCT.Core.Device.DeviceHost> item = null;

            #region  new items

            while (Identified_ItemsToAdd.TryDequeue(out item))
            {
                updateIdentifiedList = true;
                if (item.Device.InternalComLayer != null)
                {

                    item.ViewItem = new ListViewItem(item.Device.InternalComLayer.Title)
                    {
                        Tag = item
                    };
                    item.ViewItem.SubItems.AddRange(new string[]
                   {
                                 item.Device.IsConnected.ToString(),
                                 item.Device.SN,
                                 item.Device.InternalComLayer.ParentTunnel.Name
                   });
                    item.ViewItem.ForeColor = item.Device.IsConnected ? Color.Blue : Color.Gray;
                    item.ActionToDo = DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.New;

                    identifiedToAdd.Add(item.ViewItem);
                }
            }

            #endregion

            #region update exists

            foreach (ListViewItem listItem in listViewVCTIdentified.Items)
            {
                item = listItem.Tag as DeviceRecord<VCT.Core.Device.DeviceHost>;

                switch (item.ActionToDo)
                {
                    case DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.Idle:
                    case DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.New:
                        break;
                    case DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.Update:
                        item.ViewItem.Text = item.Device.InternalComLayer == null ? item.Device.IsConnected.ToString() : item.Device.InternalComLayer.Title;
                        item.ViewItem.Tag = item;
                        item.ViewItem.SubItems.AddRange(new string[]
                        {
                                 item.Device.IsConnected.ToString(),
                                 item.Device.SN,
                                 item.Device.InternalComLayer.ParentTunnel.Name
                        });
                        item.ViewItem.ForeColor = item.Device.IsConnected ? Color.Blue : Color.Gray;
                        item.ActionToDo = DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.Idle;
                        updateIdentifiedList = true;
                        break;
                    case DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.Remove:
                        updateIdentifiedList = true;
                        break;
                }
            }

            #endregion

            if (updateIdentifiedList)
            {

                ListViewItem[] allElements = new ListViewItem[listViewVCTIdentified.Items.Count];
                listViewVCTIdentified.Items.CopyTo(allElements, 0);
                List<ListViewItem> list = allElements.ToList();
                list.RemoveAll(i => ((DeviceRecord<VCT.Core.Device.DeviceHost>)i.Tag).ActionToDo == DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.Remove);
                if (identifiedToAdd.Count > 0)
                {
                    list.AddRange(identifiedToAdd.ToArray());
                }

                listViewVCTIdentified.BeginUpdate();
                listViewVCTIdentified.Items.Clear();
                listViewVCTIdentified.Items.AddRange(list.ToArray());
                listViewVCTIdentified.EndUpdate();

                textBox_totalIdentified.Text = list.Count.ToString();
            }

            #endregion

            #region bare connections

            bool updateUnIdentifiedList = false;
            var baresToAdd = new List<ListViewItem>();
            DeviceRecord<VCT.Core.Device.DeviceHost> bareItem = null;

            #region add new

            while (Bare_ItemsToAdd.TryDequeue(out bareItem))
            {
                if (bareItem.ActionToDo == DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.New)
                {
                    updateUnIdentifiedList = true;

                    bareItem.ViewItem = new ListViewItem(bareItem.Device.InternalComLayer.Title)
                    {
                        Tag = bareItem
                    };
                    bareItem.ViewItem.SubItems.Add(bareItem.Device.IsConnected.ToString());

                    bareItem.ActionToDo = DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.Idle;
                    baresToAdd.Add(bareItem.ViewItem);
                }
            }

            #endregion

            #region  update exists

            foreach (ListViewItem listItem in listViewVCTBare.Items)
            {
                bareItem = listItem.Tag as DeviceRecord<VCT.Core.Device.DeviceHost>;

                updateUnIdentifiedList = true;

                switch (bareItem.ActionToDo)
                {
                    case DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.Idle:
                    case DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.New:
                        break;
                    case DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.Update:
                        updateUnIdentifiedList = true;
                        bareItem.ViewItem.Text = bareItem.Device.InternalComLayer.Title;
                        bareItem.ViewItem.Tag = bareItem;
                        bareItem.ViewItem.SubItems.Add(bareItem.Device.IsConnected.ToString());
                        bareItem.ActionToDo = DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.Idle;
                        break;
                    case DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.Remove:
                        updateUnIdentifiedList = true;
                        break;
                }
            }

            #endregion

            if (updateUnIdentifiedList)
            {
                ListViewItem[] allElements = new ListViewItem[listViewVCTBare.Items.Count];
                listViewVCTBare.Items.CopyTo(allElements, 0);
                List<ListViewItem> list = allElements.ToList();
                list.RemoveAll(i => ((DeviceRecord<VCT.Core.Device.DeviceHost>)i.Tag).ActionToDo == DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.Remove);
                if (baresToAdd.Count > 0)
                {
                    list.AddRange(baresToAdd.ToArray());
                }

                listViewVCTBare.BeginUpdate();
                listViewVCTBare.Items.Clear();
                listViewVCTBare.Items.AddRange(list.ToArray());
                listViewVCTBare.EndUpdate();

                textBox_totalBares.Text = list.Count.ToString();
            }
            else
            {
                timers++;
                if (timers > 10)
                {
                    timers = 0;
                    clearIdentifiedBares();
                }
            }
            #endregion
        }

        #endregion

        #region VCT events

        private void MainEventsBus_DeviceConnnection(object o, VCT.Core.Events.DeviceConnectionEventArgs e)
        {
            DeviceRecord<VCT.Core.Device.DeviceHost> _device = null;

            lock (_identifiedConnection)
            {
                for (int i = 0; i < _identifiedConnection.Count; i++)
                {
                    if (_identifiedConnection[i].Device.SN == e.Device.SN)
                    {
                        _device = _identifiedConnection[i];
                        break;
                    }
                }
            }

            //search exists connection
            if (_device != null)
            {
                _device.Device = e.Device;
                _device.ActionToDo = DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.Update;
            }
            else
            {
                //no exists connnection was found, create new
                _device = new DeviceRecord<VCT.Core.Device.DeviceHost>()
                {
                    Device = e.Device,
                    ActionToDo = DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.New
                };
                lock (_identifiedConnection)
                {
                    _identifiedConnection.Add(_device);
                }

                Identified_ItemsToAdd.Enqueue(_device);
            }

            if (_device.Device.IsConnected)
            {
                bool foundBare = false;
                lock (_bareConnection)
                {
                    int count = _bareConnection.Count;
                    //search for bare
                    for (int i = 0; i < count; i++)
                    {
                        var bare = _bareConnection[i];
                        if (bare.Device.InternalComLayer == _device.Device.InternalComLayer)
                        {
                            bare.ActionToDo = DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.Remove;
                            foundBare = true;
                            break;
                        }
                    }
                }

                if (!foundBare)
                {

                }
            }
        }

        private void MainEventsBus_DeviceUnIdentifyConnnection(object o, VCT.Core.Events.DeviceConnectionEventArgs e)
        {
            var _device = new DeviceRecord<VCT.Core.Device.DeviceHost>()
            {
                Device = e.Device,
                ActionToDo = DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.New
            };

            lock (_bareConnection)
            {
                _bareConnection.Add(_device);
            }

            Bare_ItemsToAdd.Enqueue(_device);
        }

        #endregion

        #region UI Events

        private void Protocol_FormClosed(object sender, FormClosedEventArgs e)
        {
            this.Show();
        }

        private void listViewVCTIdentified_DoubleClick(object sender, EventArgs e)
        {
            if (listViewVCTIdentified.SelectedItems.Count > 0)
            {
                var devHost = listViewVCTIdentified.SelectedItems[0].Tag as DeviceRecord<VCT.Core.Device.DeviceHost>;
                Protocol7EMonitor protocol = new Protocol7EMonitor(devHost.Device);
                protocol.FormClosed += Protocol_FormClosed;
                protocol.Show();
                this.Hide();
            }
        }

        #endregion

        private void clearIdentifiedBares()
        {
            listViewVCTBare.BeginUpdate();
            ListViewItem[] allElements = new ListViewItem[listViewVCTBare.Items.Count];
            listViewVCTBare.Items.CopyTo(allElements, 0);
            List<ListViewItem> list = allElements.ToList();
            list.RemoveAll(i => ((DeviceRecord<VCT.Core.Device.DeviceHost>)i.Tag).ActionToDo == DeviceRecord<VCT.Core.Device.DeviceHost>.Actions.Remove);
            listViewVCTBare.Items.Clear();
            listViewVCTBare.Items.AddRange(list.ToArray());
            listViewVCTBare.EndUpdate();

            textBox_totalBares.Text = list.Count.ToString();
        }

        private void linkLabel_clearBares_LinkClicked(object sender, LinkLabelLinkClickedEventArgs e)
        {
            clearIdentifiedBares();
        }
    }
}
