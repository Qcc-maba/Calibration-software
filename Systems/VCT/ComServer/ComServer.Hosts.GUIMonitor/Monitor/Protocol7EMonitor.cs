using System;
using System.Data;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace Maba.VCT.CommServer.Monitor
{
    public partial class Protocol7EMonitor : Form
    {
        #region Properties

        private VCT.Core.Device.DeviceHost Device = null;
        private string FirmwareFilePath = "";
        #endregion

        #region Ctor
        public Protocol7EMonitor()
        {
            InitializeComponent();
        }

        public Protocol7EMonitor(VCT.Core.Device.DeviceHost _dev)
            : this()
        {
            Device = _dev;
            labelSerialNumber.Text = Device.SN;
            labelDeviceConnection.Text = Device.IsConnected.ToString();
        }

        #endregion

        #region Form Buttons
        private void buttonGetTime_Click(object sender, EventArgs e)
        {
            //var res = Device.Reset();
            //res.Wait();
            //var temp = res.Result;
            //if (temp.Result)
            //{
            //    Invoke(new Action(() =>
            //    {
            //        dateTimePicker_GetTime.Value = DateTime.UtcNow - temp.Response;
            //        toolStripLabel1.Text = "Get Time Received ";
            //    }));
            //}
        }
        private void buttonSetTime_Click(object sender, EventArgs e)
        {
            //var Time2Set = DateTime.UtcNow - dateTimePickerSetTime.Value;
            //var res = Device.SetTime(Time2Set);
            //res.Wait();
            //var temp = res.Result;
            //if (temp.Result)
            //{
            //    Invoke(new Action(() =>
            //    {
            //        dateTimePicker_GetTime.Value = DateTime.UtcNow - temp.Response;
            //        toolStripLabel1.Text = "Set Time Received ";
            //    }));
            //}
        }
        private void buttonWriteCNFSend_Click(object sender, EventArgs e)
        {
            //if (string.IsNullOrEmpty(textBoxWriteCNFElementType.Text) || string.IsNullOrEmpty(textBoxWriteCNFElementOffset.Text) || string.IsNullOrEmpty(textBoxWriteCNFElementQuantity.Text) || string.IsNullOrEmpty(textBoxWriteCNFData.Text))
            //{
            //    Invoke(new Action(() =>
            //    {
            //        toolStripLabel1.Text = "Wrong Input ";
            //    }));
            //    return;
            //}
            //var elementType = byte.Parse(textBoxWriteCNFElementType.Text);
            //var elementOffset = byte.Parse(textBoxWriteCNFElementOffset.Text);
            //var elementQuantity = byte.Parse(textBoxWriteCNFElementQuantity.Text);
            //var data = ASCIIEncoding.ASCII.GetBytes(textBoxWriteCNFData.Text);

            //var res = Device.WriteCNF(elementType, elementOffset, elementQuantity, data, _WriteCNFResponse);
            //res.Wait();
            //var temp = res.Result;
            //if (temp.Result)
            //{
            //    Invoke(new Action(() =>
            //    {
            //        toolStripLabel1.Text = "Write CNF Send ";
            //    }));
            //}
        }
        private void buttonReadCNFSend_Click(object sender, EventArgs e)
        {
            var elementType = ushort.Parse(textBoxReadCNFElementType.Text);
            var elementOffset = ushort.Parse(textBoxReadCNFElementOffset.Text);
            var elementQuantity = byte.Parse(textBoxReadCNFElementQuantity.Text);

            //var res = Device.ReadCNF(elementType, elementOffset, elementQuantity, _ReadCNFResponse);
            //res.Wait();
            //var temp = res.Result;
            Invoke(new Action(() =>
            {
                toolStripLabel1.Text = "Read CNF Send ";
            }));
        }
        private void buttonLogs_Click(object sender, EventArgs e)
        {
            //var Type = ushort.Parse(textBoxLogs_LogType.Text);
            //var Count = byte.Parse(textBoxLogs_Count.Text); ;
            //var Offset = ushort.Parse(textBoxLogs_Offset.Text); ;
            //var Direction = ushort.Parse(textBoxLogs_Direction.Text) == 1 ? Common.API.RemoteProtocolService.DirectionEnum.forwards : Common.API.RemoteProtocolService.DirectionEnum.backward;
            //var eachTime = byte.Parse(textBoxLogs_EachTime.Text);
            //for (int i = 0; i < Count; Count -= eachTime)
            //{
            //    var res = Device.ReadLogs(Type, eachTime, Offset, Direction, _ReadLogsResponse);
            //    res.Wait();
            //}
        }
        private void buttonSelectUpdateFirmware_Click(object sender, EventArgs e)
        {
            if (openFileDialog1.ShowDialog() == DialogResult.OK)
            {
                FirmwareFilePath = openFileDialog1.FileName;
            }
            if (!FirmwareFilePath.EndsWith(".cgl"))
            {
                //FirmwareFilePath = Common.Hydra2ProtocolHelper.CreateHydra2BinFile(FirmwareFilePath);
            }
        }
        private void buttonSendUpdateFirmware_Click(object sender, EventArgs e)
        {
            //var res = Device.UpdateFirmware(FirmwareFilePath);
            //res.Wait();
            //var temp = res.Result;
            //if (temp.Result)
            //{
            //    this.Invoke(new Action(() =>
            //    {
            //        //toolStripProgressBar1.Value = temp.PercentageOfPerformance;
            //        //toolStripLabel1.Text = "Update version Received ";
            //    }));
            //}
        }
        private void buttonReadRTDataSend_Click(object sender, EventArgs e)
        {
            var Address = ushort.Parse(textBoxReadRTData_Address.Text);
            var dataLen = ushort.Parse(textBoxReadRTData_DataLen.Text);
            //var res = Device.ReadMemory(Address, dataLen, _ReadMemoryResponse);
            //res.Wait();
            this.Invoke(new Action(() =>
            {
                toolStripLabel1.Text = "Read RT Data Send ";
            }));
        }
        private void buttonWriteRTDataSend_Click(object sender, EventArgs e)
        {
            //ushort[] Address = new ushort[] { ushort.Parse(textBoxWriteRTData_Address.Text) };
            //ushort[] value = new ushort[] { ushort.Parse(textBoxWriteRTData_Value.Text) };
            //Common.API.RemoteProtocolService.WriteMemoryItem.ElementDataTypes[] dataType = new Common.API.RemoteProtocolService.WriteMemoryItem.ElementDataTypes[]
            //{ (Common.API.RemoteProtocolService.WriteMemoryItem.ElementDataTypes)Enum.Parse(typeof( Common.API.RemoteProtocolService.WriteMemoryItem.ElementDataTypes), (comboBoxWriteRTData_DataType.Text)) };
            //var res = Device.WriteMemory(Address, value, dataType, _WriteMemoryResponse);
            //res.Wait();
            //this.Invoke(new Action(() =>
            //{
            //    toolStripLabel1.Text = "Read RT Data Send ";
            //}));

        }
        private void buttonConnect_Click(object sender, EventArgs e)
        {
            Device.Disconnect();
            labelDeviceConnection.Text = Device.IsConnected.ToString();
        }


        #endregion

        #region Responses 

        //private void _WriteCNFResponse(Common.API.RemoteProtocolService.GetFullDateResponse res)
        //{
        //    if (res.Result)
        //    {
        //        Invoke(new Action(() =>
        //        {
        //            toolStripLabel1.Text = "Write CNF Received ";
        //        }));
        //    }
        //}

        //private void _ReadCNFResponse(Common.API.RemoteProtocolService.ReadCNFResponse res)
        //{
        //    if (res.Result)
        //    {
        //        //Invoke(new Action(() =>
        //        //{
        //        //    StringBuilder sb = new StringBuilder();
        //        //    foreach (var item in res.Items)
        //        //    {
        //        //        sb.Append(System.Environment.NewLine);
        //        //        sb.Append(item.ElementType);
        //        //        sb.Append(System.Environment.NewLine);
        //        //        sb.Append(item.ElementOffset);
        //        //        sb.Append(System.Environment.NewLine);
        //        //        sb.Append(item.ElementQuantity);
        //        //        sb.Append(System.Environment.NewLine);
        //        //        sb.Append(string.Concat(item.CNF_Data.Select(a => (a - 0x30).ToString("X2"))));
        //        //        sb.Append(System.Environment.NewLine);
        //        //    }
        //        //    textBoxReadCNFResaults.Text = sb.ToString();
        //        //    toolStripLabel1.Text = "Read CNF Received ";
        //        //}));
        //    }
        //}
     
        //private void _ReadMemoryResponse(Common.API.RemoteProtocolService.PrintTypeResponse res)
        //{
        //    //if (res.Result)
        //    //{
        //    //    Invoke(new Action(() =>
        //    //    {

        //    //        StringBuilder sb = new StringBuilder();
        //    //        foreach (var item in res.Items)
        //    //        {
        //    //            if (item.Data == null || !item.Status)
        //    //            {
        //    //                textBoxReadRTData_Resault.Text = "Error";
        //    //                toolStripLabel1.Text = "Read RT Data Error ";
        //    //            }
        //    //            else
        //    //            {
        //    //                sb.Append(System.Environment.NewLine);
        //    //                sb.Append(item.AddressRequested);
        //    //                sb.Append(System.Environment.NewLine);
        //    //                sb.Append(item.DataLen);
        //    //                sb.Append(System.Environment.NewLine);
        //    //                sb.Append(string.Concat(item.Data.Select(a => a.ToString("X2") + " ")));
        //    //                sb.Append(System.Environment.NewLine);
        //    //                textBoxReadRTData_Resault.Text = sb.ToString();
        //    //                toolStripLabel1.Text = "Read RT Data Received ";
        //    //            }
        //    //        }
        //    //    }));
        //    //}
        //}
        //private void _WriteMemoryResponse(Common.API.RemoteProtocolService.PrintResponse res)
        //{
        //    if (res.Result)
        //    {
        //        Invoke(new Action(() =>
        //        {
        //            toolStripLabel1.Text = "Write RT Data Received ";
        //        }));
        //    }
        //}
        private void _ReadLogsResponse(Common.API.RemoteProtocolService.NewResponseEventArgs res)
        {
            //var _readLogResponse = res.Response as Common.API.RemoteProtocolService.ReadLogsResponse;
            //switch (_readLogResponse.Status)
            //{
            //    case Common.API.RemoteProtocolService.LogStatus.OK:
            //        Invoke(new Action(() =>
            //        {
            //            panelLogsResaults.Enabled = true;
            //            StringBuilder sb = new StringBuilder();
            //            sb.Append(System.Environment.NewLine);
            //            sb.Append(string.Concat(_readLogResponse.LogsData.Select(a => a.ToString("X2"))));
            //            sb.Append(System.Environment.NewLine);
            //            textBoxWriteCNFData.Text = sb.ToString();
            //            toolStripLabel1.Text = "Log Send ";
            //        }));
            //        break;
            //    case Common.API.RemoteProtocolService.LogStatus.InvalidLog:
            //        Invoke(new Action(() =>
            //        {
            //            toolStripLabel1.Text = "Invalid Log";
            //        }));
            //        break;
            //    case Common.API.RemoteProtocolService.LogStatus.TimedOut:
            //        Invoke(new Action(() =>
            //        {
            //            toolStripLabel1.Text = "Timed Out";
            //        }));
            //        break;
            //    case Common.API.RemoteProtocolService.LogStatus.Rejected:
            //        Invoke(new Action(() =>
            //        {
            //            toolStripLabel1.Text = "Rejected";
            //        }));
            //        break;
            //    case Common.API.RemoteProtocolService.LogStatus.NoLogs:
            //        Invoke(new Action(() =>
            //        {
            //            toolStripLabel1.Text = "No Logs";
            //        }));
            //        break;
            //    case Common.API.RemoteProtocolService.LogStatus.LoggerEmpty:
            //        Invoke(new Action(() =>
            //        {
            //            toolStripLabel1.Text = "Logger Empty";
            //        }));
            //        break;
            //    default:
            //        break;
            //}

        }

        #endregion
    }
}
