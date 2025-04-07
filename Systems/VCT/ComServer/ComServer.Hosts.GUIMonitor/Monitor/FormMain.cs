using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Ports;
using System.Linq;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Threading.Tasks;
using System.Windows.Forms;
using Maba.VCT.ComLayer;
using Maba.VCT.CommServer.BL.HydraDevices.Device;
using Maba.VCT.CommServer.BL.HydraDevices.BLCore;
using Maba.VCT.CommServer.Core.Settings;
using Maba.VCT.Core.Settings;
using Maba.VCT.CommServer.BL.HydaDevices.BLCore;

namespace Maba.VCT.CommServer.Monitor
{
    public partial class FormMain : Form
    {
        #region Members
        public bool ComServerStart = true;
        private VCTMonitor VCTMonitor = null;
        //private ComLayer.SerialCom _serialPort = null;
        //private ComLayer.ModbusCom _Modbus = null;
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

            #region Com Server Settings

            var defaultSettings_commServer = ComServerSettings.CreateDefaultSettings();
            var defaultSettings_commServer_vct = VCTSettings.CreateDefaultSettings();

            if (StartVCT)
            {
                defaultSettings_commServer_vct.Tunnels[0].Ports = textBoxVCTPort.Text.Split(',').Select(a => int.Parse(a)).ToArray();
            }

            defaultSettings_commServer.Modules = new Core.Module[]
                {
                    new Core.Module()
                    {
                        AssemblyName = Path.GetFileNameWithoutExtension(typeof(Hydra2BLCore).Assembly.ManifestModule.Name),
                        TypeName = typeof(Hydra2BLCore).FullName
                    },
                    new Core.Module()
                    {
                        AssemblyName =Path.GetFileNameWithoutExtension(typeof(Hydra3BLCore).Assembly.ManifestModule.Name),
                        TypeName = typeof(Hydra3BLCore).FullName
                    },
                    new Core.Module()
                    {
                        AssemblyName =Path.GetFileNameWithoutExtension(typeof(Agilent34401aBLCore).Assembly.ManifestModule.Name),
                        TypeName = typeof(Agilent34401aBLCore).FullName
                    },
                    new Core.Module()
                    {
                        AssemblyName =Path.GetFileNameWithoutExtension(typeof(AdditelBLCore).Assembly.ManifestModule.Name),
                        TypeName = typeof(AdditelBLCore).FullName
                    },
                    new Core.Module()
                    {
                        AssemblyName =Path.GetFileNameWithoutExtension(typeof(OptidewBLCore).Assembly.ManifestModule.Name),
                        TypeName = typeof(OptidewBLCore).FullName
                    },
                    new Core.Module()
                    {
                        AssemblyName =Path.GetFileNameWithoutExtension(typeof(TTIBLCore).Assembly.ManifestModule.Name),
                        TypeName = typeof(TTIBLCore).FullName
                    },
                    new Core.Module()
                    {
                        AssemblyName =Path.GetFileNameWithoutExtension(typeof(InstekBLCore).Assembly.ManifestModule.Name),
                        TypeName = typeof(InstekBLCore).FullName
                    }
                };

            defaultSettings_commServer.Save();

            #endregion

            if (StartVCT)
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
                comboBoxVCTSerial.Enabled = false;
                buttonStart7EDeviceSerial.Enabled = false;

                foreach (var item in SerialPort.GetPortNames())
                {
                    comboBoxVCTSerial.Items.Add(item);
                }
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
                    comboBoxVCTSerial.Items.Add(item);
                }
                comboBoxVCTSerial.Text = SerialPort.GetPortNames().FirstOrDefault();
                groupBoxDevice7ESerial.Enabled = true;
                buttonStartServer.Text = "Stop Server";
                ComServerStart = false;
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
            Parallel.ForEach(textBoxVCTPort.Text.Split(',').Select(a => int.Parse(a)).ToArray(), SearchTCPDevice);
            //Parallel.ForEach(SerialPort.GetPortNames(), SearchCOMDevice);
            Array.ForEach(SerialPort.GetPortNames(), SearchCOMDevice);
        }

        private void SearchCOMDevice(string Com)
        {
            if (string.IsNullOrEmpty(Com))
            {
                return;
            }
            //Libs.Trace.Tracer.Info("Scan searching for COM: {0}", Com);
            Tunnel t = new Tunnel
            {
                Name = Com,
            };
            if (_comServer != null && _comServer.VCTServer != null)
            {
                IComLayer com = null;
                switch (_comServer.VCTServer.CurrentServerSettings.DeviceSettings.FirstOrDefault().IdentificationType)
                {
                    case VCT.Core.DeviceSettings.IdentificationTypes.TTI:
                    case VCT.Core.DeviceSettings.IdentificationTypes.IDN:
                        com = new SerialCom(Com, 9600, 2000, t);
                        com.Open();
                        break;
                    case VCT.Core.DeviceSettings.IdentificationTypes.Modbus:
                        com = new ModbusCom(Com, 9600, t);
                        com.Open();
                        break;
                    default:
                        break;
                }

                _comServer.VCTServer.AddDevice_Pending_ComLayer(com);
                Libs.Trace.Tracer.Info("Scan find Com: {0}", Com);
            }
        }

        private void SearchTCPDevice(int port)
        {
            Parallel.ForEach(settings.IP2Scan, item1 =>
            {
                Parallel.ForEach(item1.Keys, ip =>
                {
                    //Libs.Trace.Tracer.Info("Scan searching for ip: {0} and port {1}", ip, port);
                    var pinger = new Ping();
                    PingReply reply = pinger.Send(ip);
                    if (reply.Status == IPStatus.Success)
                    {

                        Tunnel t = new Tunnel
                        {
                            Address = ip,
                            Name = item1[ip],
                            Ports = new int[1] { port }
                        };
                        try
                        {
                            var soc = new SocketCom(ip, port, t);
                            soc.Open();
                            _comServer.VCTServer.AddDevice_Pending_ComLayer(soc);
                        }
                        catch (Exception)
                        {
                            Libs.Trace.Tracer.Info("Scan failed ip: {0}", ip);
                        }
                        Libs.Trace.Tracer.Info("Scan find ip: {0}", ip);
                    }
                });
            });
        }

        private void buttonStart7EDeviceSerial_Click(object sender, EventArgs e)
        {
            Scan();

            //this.Invoke(new Action(() =>
            //{
            //    if (buttonStart7EDeviceSerial.Text == "Start")
            //    {
            //        buttonStart7EDeviceSerial.Text = "Stop";
            //        #region Device Host Serial

            //        if (!String.IsNullOrEmpty(comboBoxVCTSerial.Text))
            //        {
            //            Tunnel t = new Tunnel
            //            {
            //                Address = comboBoxVCTSerial.Text,
            //                Name = "Serial Port",
            //                Ports = new int[1] { 9600 }

            //            };
            //            _serialPort = new ComLayer.SerialCom(comboBoxVCTSerial.Text, 9600, t);
            //            if (_comServer != null && _comServer.VCTServer != null)
            //            {
            //                _serialPort.Open();
            //                _comServer.VCTServer.AddDevice_Pending_ComLayer(_serialPort);
            //            }

            //            comboBoxVCTSerial.Items.Remove(_serialPort.PortName);
            //            comboBoxDigiSerial.Items.Remove(_serialPort.PortName);
            //        }

            //        #endregion
            //    }
            //    else
            //    {
            //        buttonStart7EDeviceSerial.Text = "Start";
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
            //}));

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
