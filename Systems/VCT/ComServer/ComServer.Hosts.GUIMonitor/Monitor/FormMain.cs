using System;
using System.IO;
using System.IO.Ports;
using System.Linq;
using System.Net.NetworkInformation;
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
        private VCTMonitor _vctMonitor = null;
        private Core.MultiBLCommServer _comServer;
        private ComServerSettings _settings;
        #endregion

        #region Ctor(s)
        public FormMain()
        {
            InitializeComponent();
            _settings = ComServerSettings.Read();
            comboBoxBaud.SelectedItem = "9600";
            comboBoxHandshake.SelectedIndex = 0; // None (DTR/DSR) — suits SCPI/34401A
            RefreshPorts();
            SetIdle();
        }
        #endregion

        #region Server lifecycle

        private bool Running { get { return _comServer != null; } }

        /// <summary>
        /// Starts the ComServer core. In serial mode NO TCP tunnels are opened (the server does not
        /// need to bind ports to work over serial); serial devices are attached via Connect.
        /// </summary>
        private void Start(bool serialOnly)
        {
            var vct = VCTSettings.CreateDefaultSettings();
            vct.Tunnels = serialOnly
                ? new Tunnel[0]                                              // serial mode: no TCP ports
                : new[] { new Tunnel { Name = "TCP", Ports = ParsePorts() } };
            vct.Save();

            var server = ComServerSettings.CreateDefaultSettings();
            server.Modules = new[]
            {
                Module(typeof(Hydra2BLCore)),
                Module(typeof(Hydra3BLCore)),
                Module(typeof(Agilent34401aBLCore)),
                Module(typeof(AdditelBLCore)),
                Module(typeof(OptidewBLCore)),
                Module(typeof(TTIBLCore)),
                Module(typeof(InstekBLCore)),
            };
            server.Save();

            _comServer = new Core.MultiBLCommServer();
            _comServer.Start();
        }

        private void Stop()
        {
            if (_comServer != null)
            {
                _comServer.Stop();
                _comServer = null;
            }
        }

        private static Core.Module Module(Type blCore)
        {
            return new Core.Module
            {
                AssemblyName = Path.GetFileNameWithoutExtension(blCore.Assembly.ManifestModule.Name),
                TypeName = blCore.FullName
            };
        }

        private int[] ParsePorts()
        {
            return textBoxVCTPort.Text
                .Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                .Select(p => p.Trim())
                .Where(p => int.TryParse(p, out _))
                .Select(int.Parse)
                .ToArray();
        }

        #endregion

        #region UI state

        // Serial is usable whether the core runs or not — clicking Connect starts a serial-only core.
        private void SetIdle()
        {
            buttonStartServer.Text = "Start Server (TCP)";
            buttonStartServer.Enabled = true;
            textBoxVCTPort.Enabled = true;
            groupBoxSerial.Enabled = true;
            buttonShowMonitorVCT.Enabled = false;
            labelStatus.Text = "Stopped";
        }

        private void SetRunning(string mode)
        {
            buttonStartServer.Text = "Stop Server";
            textBoxVCTPort.Enabled = false;
            groupBoxSerial.Enabled = true;
            buttonShowMonitorVCT.Enabled = true;
            labelStatus.Text = "Running (" + mode + ")";
        }

        private void RefreshPorts()
        {
            var previous = (comboBoxVCTSerial.SelectedItem as SerialPortInfo)?.PortName;
            comboBoxVCTSerial.Items.Clear();
            var ports = SerialPortInfo.List();
            comboBoxVCTSerial.Items.AddRange(ports.Cast<object>().ToArray());
            var restore = ports.FirstOrDefault(p => p.PortName == previous) ?? ports.FirstOrDefault();
            if (restore != null)
                comboBoxVCTSerial.SelectedItem = restore;
        }

        private Handshake SelectedHandshake()
        {
            switch (comboBoxHandshake.SelectedItem as string)
            {
                case "XON/XOFF": return Handshake.XOnXOff;
                case "RTS/CTS": return Handshake.RequestToSend;
                default: return Handshake.None;
            }
        }

        #endregion

        #region UI events

        // "Start Server (TCP)" — full mode with TCP tunnels; toggles to Stop while running.
        private void buttonStartServer_Click(object sender, EventArgs e)
        {
            if (!Running)
            {
                if (ParsePorts().Length == 0)
                {
                    MessageBox.Show("Enter at least one valid TCP port (e.g. 50000,50050), or just use Connect for serial-only.",
                        "Ports", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return;
                }
                try
                {
                    Start(serialOnly: false);
                    RefreshPorts();
                    SetRunning("TCP " + textBoxVCTPort.Text);
                }
                catch (Exception ex)
                {
                    Libs.Trace.Tracer.Info(ex.Message);
                    MessageBox.Show("Failed to start server: " + ex.Message, "Error",
                        MessageBoxButtons.OK, MessageBoxIcon.Error);
                    Stop();
                    SetIdle();
                }
            }
            else
            {
                Stop();
                SetIdle();
            }
        }

        private void buttonRefreshPorts_Click(object sender, EventArgs e)
        {
            RefreshPorts();
        }

        // "Connect" — serial device. Starts a serial-only core (no TCP ports) if not already running.
        private void buttonStart7EDeviceSerial_Click(object sender, EventArgs e)
        {
            var info = comboBoxVCTSerial.SelectedItem as SerialPortInfo;
            if (info == null || string.IsNullOrEmpty(info.PortName))
            {
                MessageBox.Show("Select a COM port first.", "Serial",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            try
            {
                if (!Running)
                {
                    Start(serialOnly: true);   // no TCP ports — serial mode
                    SetRunning("Serial");
                }
                ConnectSerial(info.PortName);
            }
            catch (Exception ex)
            {
                Libs.Trace.Tracer.Info(ex.Message);
                MessageBox.Show("Failed: " + ex.Message, "Serial",
                    MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void ConnectSerial(string com)
        {
            if (_comServer == null || _comServer.VCTServer == null)
                return;

            int baud;
            if (!int.TryParse(comboBoxBaud.Text, out baud))
                baud = 9600;

            var tunnel = new Tunnel { Name = com };
            var idType = _comServer.VCTServer.CurrentServerSettings.DeviceSettings
                .FirstOrDefault()?.IdentificationType ?? VCT.Core.DeviceSettings.IdentificationTypes.IDN;

            IComLayer layer = (idType == VCT.Core.DeviceSettings.IdentificationTypes.Modbus)
                ? (IComLayer)new ModbusCom(com, baud, tunnel)
                : new SerialCom(com, baud, 2000, tunnel) { Handshake = SelectedHandshake() };

            layer.Open();
            _comServer.VCTServer.AddDevice_Pending_ComLayer(layer);
            labelStatus.Text = "Serial connected: " + com + " @ " + baud;
            Libs.Trace.Tracer.Info("Serial connected: {0} @ {1}", com, baud);
        }

        private void buttonShowMonitorVCT_Click(object sender, EventArgs e)
        {
            if (_comServer == null || _comServer.VCTServer == null)
                return;
            _vctMonitor = new VCTMonitor(_comServer.VCTServer);
            _vctMonitor.FormClosed += (s, args) => this.Show();
            _vctMonitor.Show();
            this.Hide();
        }

        #endregion
    }
}
