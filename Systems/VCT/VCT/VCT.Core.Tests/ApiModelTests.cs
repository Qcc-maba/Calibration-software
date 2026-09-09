using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.Common.API;
using Maba.VCT.Common.API.RemoteProtocolService;

namespace Maba.VCT.Core.Tests
{
    [TestClass]
    public class ApiModelTests
    {
        #region BaseRequest Tests

        [TestMethod]
        public void BaseRequest_Constructor_SetsCreationDate()
        {
            var before = DateTime.UtcNow;
            var request = new BaseRequest();
            var after = DateTime.UtcNow;

            Assert.IsTrue(request.CreationDate >= before && request.CreationDate <= after);
            Assert.IsTrue(request.LastRequestHandling >= before && request.LastRequestHandling <= after);
        }

        [TestMethod]
        public void BaseRequest_Packet_DefaultIsNull()
        {
            var request = new BaseRequest();

            Assert.IsNull(request.Packet);
        }

        [TestMethod]
        public void BaseRequest_CallBackResponse_DefaultIsNull()
        {
            var request = new BaseRequest();

            Assert.IsNull(request.CallBackResponse);
        }

        [TestMethod]
        public void BaseRequest_Packet_CanBeSet()
        {
            var request = new BaseRequest();
            var packet = new HardwarePacket("CMD\r\n", true);
            request.Packet = packet;

            Assert.AreSame(packet, request.Packet);
        }

        [TestMethod]
        public void BaseRequest_CallBackResponse_CanBeSet()
        {
            var request = new BaseRequest();
            bool callbackCalled = false;
            request.CallBackResponse = (o, e) => { callbackCalled = true; };
            request.CallBackResponse(null, null);

            Assert.IsTrue(callbackCalled);
        }

        [TestMethod]
        public void BaseRequest_TTL_DefaultIsZero()
        {
            var request = new BaseRequest();

            Assert.AreEqual(0, request.TTL);
        }

        [TestMethod]
        public void BaseRequest_TTL_CanBeSet()
        {
            var request = new BaseRequest();
            request.TTL = 30;

            Assert.AreEqual(30, request.TTL);
        }

        [TestMethod]
        public void BaseRequest_ExpectedResponse_DefaultIsFalse()
        {
            var request = new BaseRequest();

            Assert.IsFalse(request.ExpectedResponse);
        }

        #endregion

        #region BaseResponse Tests

        [TestMethod]
        public void BaseResponse_DefaultConstructor_ResultIsFalse()
        {
            var response = new BaseResponse();

            Assert.IsFalse(response.Result);
        }

        [TestMethod]
        public void BaseResponse_BoolConstructor_SetsResult()
        {
            var responseTrue = new BaseResponse(true);
            var responseFalse = new BaseResponse(false);

            Assert.IsTrue(responseTrue.Result);
            Assert.IsFalse(responseFalse.Result);
        }

        [TestMethod]
        public void BaseResponse_Message_DefaultIsNull()
        {
            var response = new BaseResponse();

            Assert.IsNull(response.Message);
        }

        [TestMethod]
        public void BaseResponse_Message_CanBeSet()
        {
            var response = new BaseResponse();
            response.Message = "test message";

            Assert.AreEqual("test message", response.Message);
        }

        [TestMethod]
        public void BaseResponse_SN_DefaultIsNull()
        {
            var response = new BaseResponse();

            Assert.IsNull(response.SN);
        }

        [TestMethod]
        public void BaseResponse_SN_CanBeSet()
        {
            var response = new BaseResponse();
            response.SN = "FLUKE,2625A";

            Assert.AreEqual("FLUKE,2625A", response.SN);
        }

        [TestMethod]
        public void BaseResponse_HasResponse_DefaultIsFalse()
        {
            var response = new BaseResponse();

            Assert.IsFalse(response.HasResponse);
        }

        [TestMethod]
        public void BaseResponse_Expired_DefaultIsFalse()
        {
            var response = new BaseResponse();

            Assert.IsFalse(response.Expired);
        }

        #endregion

        #region InitSystemRequest Tests

        [TestMethod]
        public void InitSystemRequest_InheritsFromBaseRequest()
        {
            var request = new InitSystemRequest();

            Assert.IsInstanceOfType(request, typeof(BaseRequest));
        }

        [TestMethod]
        public void InitSystemRequest_CanSetPacket()
        {
            var request = new InitSystemRequest();
            var packet = new HardwarePacket("*RST\r\n", true);
            request.Packet = packet;

            Assert.AreSame(packet, request.Packet);
        }

        #endregion

        #region InitSystemResponse Tests

        [TestMethod]
        public void InitSystemResponse_BoolConstructor_SetsResult()
        {
            var response = new InitSystemResponse(true);

            Assert.IsTrue(response.Result);
        }

        [TestMethod]
        public void InitSystemResponse_PacketConstructor_SetsResultFromOK()
        {
            var okPacket = new HardwarePacket("response\r\n");
            var response = new InitSystemResponse(okPacket);

            Assert.IsTrue(response.Result);
            Assert.AreEqual("response\r\n", response.Message);
        }

        [TestMethod]
        public void InitSystemResponse_PacketConstructor_NotOK_ResultFalse()
        {
            var notOkPacket = new HardwarePacket("no newline");
            var response = new InitSystemResponse(notOkPacket);

            Assert.IsFalse(response.Result);
        }

        #endregion

        #region GetSetDateRequest Tests

        [TestMethod]
        public void GetSetDateRequest_InheritsFromBaseRequest()
        {
            var request = new GetSetDateRequest();

            Assert.IsInstanceOfType(request, typeof(BaseRequest));
        }

        #endregion

        #region GetSetDateResponse Tests

        [TestMethod]
        public void GetSetDateResponse_BoolConstructor_SetsResult()
        {
            var responseTrue = new GetSetDateResponse(true);
            var responseFalse = new GetSetDateResponse(false);

            Assert.IsTrue(responseTrue.Result);
            Assert.IsFalse(responseFalse.Result);
        }

        #endregion

        #region RateRequest Tests

        [TestMethod]
        public void RateRequest_InheritsFromBaseRequest()
        {
            var request = new RateRequest();

            Assert.IsInstanceOfType(request, typeof(BaseRequest));
        }

        [TestMethod]
        public void RateRequest_IntervalConstructor_SetsTimeComponents()
        {
            // Constructor order is (intervalSeconds, intervalMinutes, intervalHours).
            var request = new RateRequest(0, 30, 1);

            Assert.AreEqual(1, request.IntervalHours);
            Assert.AreEqual(30, request.IntervalMinutes);
            Assert.AreEqual(0, request.IntervalSeconds);
        }

        #endregion

        #region RateResponse Tests

        [TestMethod]
        public void RateResponse_BoolConstructor_SetsResult()
        {
            var response = new RateResponse(true);

            Assert.IsTrue(response.Result);
        }

        [TestMethod]
        public void RateResponse_FalseResult()
        {
            var response = new RateResponse(false);

            Assert.IsFalse(response.Result);
        }

        #endregion

        #region LogsRequest Tests

        [TestMethod]
        public void LogsRequest_Constructor_SetsLogCommand()
        {
            var request = new LogsRequest(LogsRequest.LogCommands.ClearLogs);

            Assert.AreEqual(LogsRequest.LogCommands.ClearLogs, request.LogCommand);
        }

        [TestMethod]
        public void LogsRequest_AllLogCommands_HaveExpectedValues()
        {
            Assert.AreEqual(0, (int)LogsRequest.LogCommands.StopScan);
            Assert.AreEqual(1, (int)LogsRequest.LogCommands.StartScan);
            Assert.AreEqual(2, (int)LogsRequest.LogCommands.ClearLogs);
            Assert.AreEqual(3, (int)LogsRequest.LogCommands.LogCount);
            Assert.AreEqual(4, (int)LogsRequest.LogCommands.GetLogs);
        }

        [TestMethod]
        public void LogsRequest_StopScan()
        {
            var request = new LogsRequest(LogsRequest.LogCommands.StopScan);
            Assert.AreEqual(LogsRequest.LogCommands.StopScan, request.LogCommand);
        }

        [TestMethod]
        public void LogsRequest_StartScan()
        {
            var request = new LogsRequest(LogsRequest.LogCommands.StartScan);
            Assert.AreEqual(LogsRequest.LogCommands.StartScan, request.LogCommand);
        }

        [TestMethod]
        public void LogsRequest_GetLogs()
        {
            var request = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            Assert.AreEqual(LogsRequest.LogCommands.GetLogs, request.LogCommand);
        }

        #endregion

        #region InitChannelsRequest Tests

        [TestMethod]
        public void InitChannelsRequest_InheritsFromBaseRequest()
        {
            var request = new InitChannelsRequest();

            Assert.IsInstanceOfType(request, typeof(BaseRequest));
        }

        [TestMethod]
        public void InitChannelsRequest_WithChannelNumber()
        {
            var request = new InitChannelsRequest(5);

            Assert.IsInstanceOfType(request, typeof(BaseRequest));
        }

        #endregion

        #region InitChannelsResponse Tests

        [TestMethod]
        public void InitChannelsResponse_BoolConstructor_SetsResult()
        {
            var response = new InitChannelsResponse(true);

            Assert.IsTrue(response.Result);
        }

        [TestMethod]
        public void InitChannelsResponse_FalseResult()
        {
            var response = new InitChannelsResponse(false);

            Assert.IsFalse(response.Result);
        }

        #endregion

        #region LogsResponse Constructor Tests

        [TestMethod]
        public void LogsResponse_AllLogCommands_CanBeUsedInConstructor()
        {
            foreach (LogsRequest.LogCommands cmd in Enum.GetValues(typeof(LogsRequest.LogCommands)))
            {
                var response = new LogsResponse(true, cmd);
                Assert.AreEqual(cmd, response.LogCommand);
                Assert.IsTrue(response.Result);
            }
        }

        #endregion
    }
}
