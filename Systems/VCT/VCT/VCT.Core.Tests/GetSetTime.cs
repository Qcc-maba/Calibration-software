using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Net;
using System.Linq;
using System.Diagnostics;

namespace Maba.VCT.Core.Tests
{
    //[TestClass]
    //public class GetSetTime : TestInit
    //{
    //    #region Members

    //    private System.Threading.ManualResetEvent _setTimeFlag = new System.Threading.ManualResetEvent(false);
    //    private System.Threading.ManualResetEvent _getTimeFlag = new System.Threading.ManualResetEvent(false);
    //    TimeSpan time2set;
    //    private static int port = 50100;
    //    //Common.API.RemoteProtocolService.ResetResponse resposeGetTime;
    //    //Common.API.RemoteProtocolService.SetTimeResponse responseSetTime;
     
    //    #endregion

    //    #region Ctor
    //    public GetSetTime() : base(port)
    //    {
    //    }
    //    #endregion

    //    #region Tests

    //    [TestMethod]
    //    //public void GetSetTimeTest()
    //    //{
    //    //    System.Threading.Thread.Sleep(5000);
    //    //    time2set = TimeSpan.FromHours(1);

    //    //    string sn = null;
    //    //    for (int i = 0; i < MaxRemoteDevices; i++)
    //    //    {
    //    //        responseSetTime = null;
    //    //        sn = i.ToString().PadLeft(16, '0');
    //    //        var device = Server.GetDevice(sn);
    //    //        var SetTimeResponse = device.SetTime(time2set, setTimeRespose);
    //    //        SetTimeResponse.Wait();
    //    //        Assert.IsNotNull(SetTimeResponse.Result);

    //    //        Assert.IsTrue(_setTimeFlag.WaitOne(1000));
    //    //        responseSetTime = SetTimeResponse.Result;
    //    //        Assert.IsTrue(responseSetTime.Result);

    //    //        resposeGetTime = null;
    //    //        var GetTimeResponse = device.Reset(getTimeRespose);
    //    //        GetTimeResponse.Wait();
    //    //        Assert.IsNotNull(GetTimeResponse.Result);
    //    //        resposeGetTime = GetTimeResponse.Result;
    //    //        Assert.IsTrue(_getTimeFlag.WaitOne(1000));
    //    //        Assert.IsTrue(resposeGetTime.Result);
    //    //        Assert.IsTrue((resposeGetTime.Response - time2set).TotalSeconds < TimeSpan.FromSeconds(1).TotalSeconds);
    //    //    }
    //    //}

    //    #endregion

    //    #region private methods
    //    //private void getTimeRespose(Common.API.RemoteProtocolService.ResetResponse Response)
    //    //{
    //    //    resposeGetTime = Response;
    //    //    Assert.IsTrue(Response.Result);
    //    //    Assert.IsTrue(Math.Abs((Response.Response - time2set).TotalSeconds) < TimeSpan.FromSeconds(1).TotalSeconds);

    //    //    _getTimeFlag.Set();
    //    //}
    //    //private void setTimeRespose(Common.API.RemoteProtocolService.SetTimeResponse Response)
    //    //{
    //    //    responseSetTime = Response;
    //    //    Assert.IsTrue(Response.Result);
    //    //    _setTimeFlag.Set();
    //    //}
    //    #endregion
    //}
}
