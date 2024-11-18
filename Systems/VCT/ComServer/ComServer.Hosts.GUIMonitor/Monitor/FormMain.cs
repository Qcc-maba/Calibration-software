using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Ports;
using System.Linq;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Windows.Forms;
using Maba.VCT.ComLayer;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.CommServer.Core.Settings;
using Maba.VCT.Core.Settings;

namespace Maba.VCT.CommServer.Monitor
{
    public partial class FormMain : Form
    {
        #region Members
        public bool ComServerStart = true;
        private VCTMonitor VCTMonitor = null;
        private DigiMonitor DigiMonitor = null;
        private ComLayer.SerialCom _serialPort = null;
        private Core.MultiBLCommServer _comServer;
        private ComServerSettings settings;
        #endregion

        #region Ctor(s)
        public FormMain()
        {
            InitializeComponent();

            settings = Core.Settings.ComServerSettings.Read();

        }
        #endregion

        #region Private methods

        private void Stop()
        {
            if (_comServer != null)
            {
                _comServer.Stop();
                _comServer = null;
            }
        }

        private void Start()
        {
            var StartVCT = groupBoxDevice7ESerial.Enabled;
            var StartDigi = groupBoxDigiSerial.Enabled;

            #region Com Server Settings

            var defaultSettings_commServer = Core.Settings.ComServerSettings.CreateDefaultSettings();
            var defaultSettings_commServer_vct = VCT.Core.Settings.VCTSettings.CreateDefaultSettings();

            if (StartVCT)
            {
                defaultSettings_commServer_vct.Tunnels[0].Ports = textBoxVCTPort.Text.Split(',').Select(a => int.Parse(a)).ToArray();
            }

            defaultSettings_commServer.Modules = new Core.Module[]
                {
                    new Core.Module()
                    {
                        AssemblyName = Path.GetFileNameWithoutExtension(typeof(Hydra2BLCore).Assembly.ManifestModule.Name),
                        TypeName = typeof(BL.HydraDevices.BLCore.Hydra2BLCore).FullName
                    },
                    new Core.Module()
                    {
                        AssemblyName =Path.GetFileNameWithoutExtension(typeof(Hydra3BLCore).Assembly.ManifestModule.Name),
                        TypeName = typeof(BL.HydraDevices.BLCore.Hydra3BLCore).FullName
                    }
                };

            defaultSettings_commServer.Save();

            #endregion

            if (StartVCT || StartDigi)
            {
                _comServer = new Core.MultiBLCommServer();
                _comServer.Start();
            }
        }

        private void Init()
        {
            Invoke(new Action(() =>
            {
                buttonStartServer.Text = "Start Server";
                ComServerStart = true;
                buttonStartServer.Enabled = true;
                comboBoxDigiSerial.Enabled = false;
                comboBoxVCTSerial.Enabled = false;
                buttonStartDigiSerial.Enabled = false;
                buttonStart7EDeviceSerial.Enabled = false;

                foreach (var item in SerialPort.GetPortNames())
                {
                    comboBoxDigiSerial.Items.Add(item);
                    comboBoxVCTSerial.Items.Add(item);
                }
                comboBoxDigiSerial.Text = SerialPort.GetPortNames().FirstOrDefault();
                comboBoxVCTSerial.Text = SerialPort.GetPortNames().FirstOrDefault();
            }));
        }

        #endregion

        #region UI events

        void Monitor_FormClosed(object sender, FormClosedEventArgs e)
        {
            Init();
            this.Show();
        }

        private void buttonStartServer_Click(object sender, EventArgs e)
        {
            if (ComServerStart)
            {
                foreach (var item in SerialPort.GetPortNames())
                {
                    comboBoxDigiSerial.Items.Add(item);
                    comboBoxVCTSerial.Items.Add(item);
                }
                comboBoxDigiSerial.Text = SerialPort.GetPortNames().FirstOrDefault();
                comboBoxVCTSerial.Text = SerialPort.GetPortNames().FirstOrDefault();
                groupBoxDevice7ESerial.Enabled = true;
                buttonStartServer.Text = "Stop Server";
                ComServerStart = false;
                comboBoxDigiSerial.Enabled = true;
                comboBoxVCTSerial.Enabled = true;
                Start();
            }
            else
            {
                Init();
                Stop();
            }
        }

        private void Scan()
        {
            int port = 3490;
            var pinger = new Ping();
            for (int i = 31; i < 50; i++)
            {
                string ip = "10.3.3." + i.ToString();

                PingReply reply = pinger.Send(ip);
                if (reply.Status == IPStatus.Success)
                {
                    Tunnel t = new Tunnel
                    {
                        Address = comboBoxVCTSerial.Text,
                        Name = "Serial Port",
                        Ports = new int[1] { 9600 }

                    };
                    var soc = new SocketCom(ip, port, t);
                    soc.Open();
                    _comServer.VCTServer.AddDevice_Pending_ComLayer(soc);
                    Libs.Trace.Tracer.Info("Scan find ip: {0}", ip);

                }
            }
        }

        private void buttonStart7EDeviceSerial_Click(object sender, EventArgs e)
        {
            Scan();
            this.Invoke(new Action(() =>
            {
                if (buttonStart7EDeviceSerial.Text == "Start")
                {
                    buttonStart7EDeviceSerial.Text = "Stop";
                    #region Device Host Serial

                    if (!String.IsNullOrEmpty(comboBoxVCTSerial.Text))
                    {
                        Tunnel t = new Tunnel
                        {
                            Address = comboBoxVCTSerial.Text,
                            Name = "Serial Port",
                            Ports = new int[1] { 9600 }

                        };
                        _serialPort = new ComLayer.SerialCom(comboBoxVCTSerial.Text, 9600, t);
                        if (_comServer != null && _comServer.VCTServer != null)
                        {
                            _serialPort.Open();
                            _comServer.VCTServer.AddDevice_Pending_ComLayer(_serialPort);
                        }

                        comboBoxVCTSerial.Items.Remove(_serialPort.PortName);
                        comboBoxDigiSerial.Items.Remove(_serialPort.PortName);
                    }

                    #endregion
                }
                else
                {
                    buttonStart7EDeviceSerial.Text = "Start";
                    if (_serialPort != null && !string.IsNullOrEmpty(_serialPort.PortName))
                    {
                        comboBoxVCTSerial.Items.Add(_serialPort.PortName);
                        comboBoxDigiSerial.Items.Add(_serialPort.PortName);
                    }

                    if (_serialPort.IsConnected)
                    {
                        _serialPort.Close();
                        _serialPort = null;
                    }
                }
            }));
        }

        private void buttonStartDigiSerial_Click(object sender, EventArgs e)
        {

            //#region Digi Serial
            //if (buttonStartDigiSerial.Text == "Start")
            //{
            //    buttonStartDigiSerial.Text = "Stop";
            //    if (!String.IsNullOrEmpty(comboBoxDigiSerial.Text))
            //    {
            //        _serialPort = new ComLayer.SerialCom(comboBoxDigiSerial.Text, 9600);
            //        if (_comServer != null && _comServer.DigiGatewayCore != null)
            //        {
            //            _serialPort.Open();
            //            _comServer.DigiGatewayCore.AddAPIComLayer(_serialPort);
            //        }
            //        this.Invoke(new Action(() =>
            //        {
            //            comboBoxVCTSerial.Items.Remove(_serialPort.PortName);
            //            comboBoxDigiSerial.Items.Remove(_serialPort.PortName);
            //        }));
            //    }
            //    else
            //    {
            //        buttonStartDigiSerial.Text = "Start";
            //        if (_serialPort != null && !string.IsNullOrEmpty(_serialPort.PortName))
            //        {
            //            comboBoxVCTSerial.Items.Add(_serialPort.PortName);
            //            comboBoxDigiSerial.Items.Add(_serialPort.PortName);
            //        }

            //        if (_serialPort.IsConnected)
            //        {
            //            _serialPort.Close();
            //            _serialPort = null;
            //        }
            //    }
            //}
            //#endregion

        }

        private void buttonShowMonitorVCT_Click(object sender, EventArgs e)
        {
            VCTMonitor = new VCTMonitor(_comServer.VCTServer);
            VCTMonitor.Show();
            VCTMonitor.FormClosed += Monitor_FormClosed;
            this.Hide();
        }

        private void buttonShowMonitorDigi_Click(object sender, EventArgs e)
        {
            //DigiMonitor = new DigiMonitor(_comServer);
            //DigiMonitor.Show();
            //DigiMonitor.FormClosed += Monitor_FormClosed;
            //this.Hide();
        }
        #endregion
    }
}
