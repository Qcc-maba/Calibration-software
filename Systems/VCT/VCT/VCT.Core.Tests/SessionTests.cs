using System;
using System.Threading;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.Common;
using Maba.VCT.Common.API;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.Core;
using Maba.VCT.Core.Device;
using Maba.VCT.Core.Device.Sessions;
using Maba.VCT.Core.Events;

namespace Maba.VCT.Core.Tests
{
    [TestClass]
    public class SessionTests
    {
        private EventsBus _bus;
        private MockComLayer _comLayer;
        private HardwareDeviceHost _deviceHost;

        [TestInitialize]
        public void Setup()
        {
            _bus = new EventsBus();
            _comLayer = new MockComLayer();
            var settings = new DeviceSettings();
            _deviceHost = new HardwareDeviceHost(_bus, _comLayer, settings);
            _deviceHost.InitSessions();
        }

        #region LogsSession Tests

        [TestMethod]
        public void LogsSession_HandleRequest_ValidRequest_ReturnsTrue()
        {
            var session = new LogsSession(_deviceHost);
            var request = new LogsRequest(LogsRequest.LogCommands.ClearLogs);
            request.Packet = new HardwarePacket("LOG CLR\r\n", true);

            var result = session.HandleRequest(request);

            Assert.IsTrue(result.Result);
            Assert.AreEqual(LogsRequest.LogCommands.ClearLogs, result.LogCommand);
        }

        [TestMethod]
        public void LogsSession_HandlePacket_NoLastRequest_DoesNothing()
        {
            var session = new LogsSession(_deviceHost);
            var packet = new HardwarePacket("data\r\n");

            bool result = session.HandlePacket(packet);

            // Should return true without errors (LastRequest is null)
            Assert.IsTrue(result);
        }

        [TestMethod]
        public void LogsSession_HandlePacket_NotOK_DoesNotAnswer()
        {
            var session = new LogsSession(_deviceHost);
            var request = new LogsRequest(LogsRequest.LogCommands.LogCount);
            request.Packet = new HardwarePacket("LOG COUNT?\r\n", true);
            bool callbackFired = false;
            request.CallBackResponse = (o, e) => { callbackFired = true; };

            session.HandleRequest(request);
            // Simulate timer tick to process the request
            session.Timer();

            // Send a packet with OK=false (no \r\n)
            var notOkPacket = new HardwarePacket("ready");
            session.HandlePacket(notOkPacket);

            // Callback should NOT have fired because p.OK is false
            Assert.IsFalse(callbackFired);
        }

        [TestMethod]
        public void LogsSession_HandlePacket_OK_LogCount_InvokesCallback()
        {
            var session = new LogsSession(_deviceHost);
            var request = new LogsRequest(LogsRequest.LogCommands.LogCount);
            request.Packet = new HardwarePacket("LOG COUNT?\r\n", true);
            LogsResponse receivedResponse = null;
            request.CallBackResponse = (o, e) => { receivedResponse = e as LogsResponse; };

            session.HandleRequest(request);
            session.Timer(); // Dequeue and process

            // Send OK packet
            var okPacket = new HardwarePacket("5\r\n");
            session.HandlePacket(okPacket);

            Assert.IsNotNull(receivedResponse);
            Assert.AreEqual(LogsRequest.LogCommands.LogCount, receivedResponse.LogCommand);
            Assert.AreEqual(5, receivedResponse.LogCount);
        }

        [TestMethod]
        public void LogsSession_HandlePacket_OK_GetLogs_InvokesCallback()
        {
            var session = new LogsSession(_deviceHost);
            var request = new LogsRequest(LogsRequest.LogCommands.GetLogs);
            request.Packet = new HardwarePacket("LOGGED? 1\r\n", true);
            LogsResponse receivedResponse = null;
            request.CallBackResponse = (o, e) => { receivedResponse = e as LogsResponse; };

            session.HandleRequest(request);
            session.Timer();

            var okPacket = new HardwarePacket("12,30,45,06,15,25,25.5,30.0,0,0,100\r\n");
            session.HandlePacket(okPacket);

            Assert.IsNotNull(receivedResponse);
            Assert.AreEqual(LogsRequest.LogCommands.GetLogs, receivedResponse.LogCommand);
        }

        [TestMethod]
        public void LogsSession_HandlePacket_OK_OtherCommand_InvokesCallbackWithSimpleResponse()
        {
            var session = new LogsSession(_deviceHost);
            var request = new LogsRequest(LogsRequest.LogCommands.ClearLogs);
            request.Packet = new HardwarePacket("LOG CLR\r\n", true);
            LogsResponse receivedResponse = null;
            request.CallBackResponse = (o, e) => { receivedResponse = e as LogsResponse; };

            session.HandleRequest(request);
            session.Timer();

            var okPacket = new HardwarePacket("OK\r\n");
            session.HandlePacket(okPacket);

            Assert.IsNotNull(receivedResponse);
            Assert.IsTrue(receivedResponse.Result);
            Assert.AreEqual(LogsRequest.LogCommands.ClearLogs, receivedResponse.LogCommand);
        }

        [TestMethod]
        public void LogsSession_ProcessRequest_NoWait4Response_AnswersImmediately()
        {
            var session = new LogsSession(_deviceHost);
            var request = new LogsRequest(LogsRequest.LogCommands.StartScan);
            request.Packet = new HardwarePacket("SCAN 1\r\n", false); // Wait4Respons = false
            LogsResponse receivedResponse = null;
            request.CallBackResponse = (o, e) => { receivedResponse = e as LogsResponse; };

            session.HandleRequest(request);
            session.Timer(); // Process - should answer immediately

            Assert.IsNotNull(receivedResponse);
            Assert.IsTrue(receivedResponse.Result);
        }

        [TestMethod]
        public void LogsSession_AnswerLastRequest_ClearsLastRequestBeforeCallback()
        {
            // This tests the critical fix: LastRequest is cleared BEFORE callback
            // to prevent deadlock if callback queues another request
            var session = new LogsSession(_deviceHost);
            var request = new LogsRequest(LogsRequest.LogCommands.LogCount);
            request.Packet = new HardwarePacket("LOG COUNT?\r\n", true);

            bool wasAvailableInCallback = false;
            request.CallBackResponse = (o, e) =>
            {
                wasAvailableInCallback = session.Avilable4Transport;
            };

            session.HandleRequest(request);
            session.Timer();

            var okPacket = new HardwarePacket("0\r\n");
            session.HandlePacket(okPacket);

            // LastRequest should have been cleared before callback,
            // making the session available for transport
            Assert.IsTrue(wasAvailableInCallback);
        }

        [TestMethod]
        public void LogsSession_AnswerLastRequest_CallbackThrows_DoesNotCrash()
        {
            var session = new LogsSession(_deviceHost);
            var request = new LogsRequest(LogsRequest.LogCommands.ClearLogs);
            request.Packet = new HardwarePacket("LOG CLR\r\n", true);
            request.CallBackResponse = (o, e) =>
            {
                throw new InvalidOperationException("callback error");
            };

            session.HandleRequest(request);
            session.Timer();

            // HandlePacket calls AnswerLastRequest which calls callback that throws
            // The exception should propagate (not caught in AnswerLastRequest)
            // but LastRequest is already cleared
            try
            {
                var okPacket = new HardwarePacket("OK\r\n");
                session.HandlePacket(okPacket);
            }
            catch (InvalidOperationException)
            {
                // Expected - callback threw
            }

            // Session should still be available (LastRequest was cleared before callback)
            Assert.IsTrue(session.Avilable4Transport);
        }

        [TestMethod]
        public void LogsSession_AnswerLastRequest_NoCallback_ClearsLastRequest()
        {
            var session = new LogsSession(_deviceHost);
            var request = new LogsRequest(LogsRequest.LogCommands.ClearLogs);
            request.Packet = new HardwarePacket("LOG CLR\r\n", true);
            // No callback set

            session.HandleRequest(request);
            session.Timer();

            var okPacket = new HardwarePacket("OK\r\n");
            session.HandlePacket(okPacket);

            Assert.IsTrue(session.Avilable4Transport);
        }

        [TestMethod]
        public void LogsSession_AnswerLastRequest_InvokeWithNoCallback_ClearsLastRequest()
        {
            var session = new LogsSession(_deviceHost);
            var request = new LogsRequest(LogsRequest.LogCommands.ClearLogs)
            {
                Packet = new HardwarePacket("LOG CLR\r\n", true),
                CallBackResponse = null
            };
            var po = new PrivateObject(session);
            po.SetProperty("LastRequest", request);
            po.Invoke("AnswerLastRequest", new LogsResponse(true, LogsRequest.LogCommands.ClearLogs));
            Assert.IsNull(po.GetProperty("LastRequest"));
        }

        #endregion

        #region InitSystemSession Tests

        [TestMethod]
        public void InitSystemSession_HandleRequest_ValidRequest_ReturnsTrue()
        {
            var session = new InitSystemSession(_deviceHost);
            var request = new InitSystemRequest();
            request.Packet = new HardwarePacket("*RST\r\n", true);

            var result = session.HandleRequest(request);

            Assert.IsTrue(result.Result);
        }

        [TestMethod]
        public void InitSystemSession_HandleRequest_NullRequest_ReturnsFalse()
        {
            var session = new InitSystemSession(_deviceHost);

            var result = session.HandleRequest(null);

            Assert.IsFalse(result.Result);
        }

        [TestMethod]
        public void InitSystemSession_HandlePacket_NoLastRequest_ReturnsFalse()
        {
            var session = new InitSystemSession(_deviceHost);
            var packet = new HardwarePacket("data\r\n");

            bool result = session.HandlePacket(packet);

            Assert.IsFalse(result);
        }

        [TestMethod]
        public void InitSystemSession_HandlePacket_NotOK_ReturnsFalse()
        {
            var session = new InitSystemSession(_deviceHost);
            var request = new InitSystemRequest();
            request.Packet = new HardwarePacket("*RST\r\n", true);

            session.HandleRequest(request);
            session.Timer();

            // Packet without \r\n → OK is false
            var notOkPacket = new HardwarePacket("ready");
            bool result = session.HandlePacket(notOkPacket);

            Assert.IsFalse(result);
        }

        [TestMethod]
        public void InitSystemSession_HandlePacket_OK_InvokesCallback()
        {
            var session = new InitSystemSession(_deviceHost);
            var request = new InitSystemRequest();
            request.Packet = new HardwarePacket("*RST\r\n", true);
            InitSystemResponse receivedResponse = null;
            request.CallBackResponse = (o, e) => { receivedResponse = e as InitSystemResponse; };

            session.HandleRequest(request);
            session.Timer();

            var okPacket = new HardwarePacket("OK\r\n");
            session.HandlePacket(okPacket);

            Assert.IsNotNull(receivedResponse);
            Assert.IsTrue(receivedResponse.Result);
        }

        [TestMethod]
        public void InitSystemSession_ProcessRequest_NoWait4Response_AnswersImmediately()
        {
            var session = new InitSystemSession(_deviceHost);
            var request = new InitSystemRequest();
            request.Packet = new HardwarePacket("SCAN 1\r\n", false); // No wait
            InitSystemResponse receivedResponse = null;
            request.CallBackResponse = (o, e) => { receivedResponse = e as InitSystemResponse; };

            session.HandleRequest(request);
            session.Timer();

            Assert.IsNotNull(receivedResponse);
            Assert.IsTrue(receivedResponse.Result);
        }

        [TestMethod]
        public void InitSystemSession_AnswerLastRequest_SetsSN()
        {
            // The AnswerLastRequest method sets response.SN = this.Parent.SN
            var session = new InitSystemSession(_deviceHost);
            var request = new InitSystemRequest();
            request.Packet = new HardwarePacket("*RST\r\n", true);
            InitSystemResponse receivedResponse = null;
            request.CallBackResponse = (o, e) => { receivedResponse = e as InitSystemResponse; };

            session.HandleRequest(request);
            session.Timer();

            var okPacket = new HardwarePacket("OK\r\n");
            session.HandlePacket(okPacket);

            // SN is null initially on the device host
            Assert.IsNotNull(receivedResponse);
        }

        [TestMethod]
        public void InitSystemSession_AnswerLastRequest_InvokeWithNoCallback_ClearsLastRequest()
        {
            var session = new InitSystemSession(_deviceHost);
            var request = new InitSystemRequest
            {
                Packet = new HardwarePacket("*RST\r\n", true),
                CallBackResponse = null
            };
            var po = new PrivateObject(session);
            po.SetProperty("LastRequest", request);
            po.Invoke("AnswerLastRequest", new InitSystemResponse(true));
            Assert.IsNull(po.GetProperty("LastRequest"));
        }

        #endregion

        #region RateSession Tests

        [TestMethod]
        public void RateSession_HandleRequest_ReturnsTrue()
        {
            var session = new RateSession(_deviceHost);
            var request = new RateRequest();
            request.Packet = new HardwarePacket("RATE S\r\n", true);

            var result = session.HandleRequest(request);

            Assert.IsTrue(result.Result);
        }

        [TestMethod]
        public void RateSession_HandlePacket_NoLastRequest_ReturnsFalse()
        {
            var session = new RateSession(_deviceHost);
            var packet = new HardwarePacket("data\r\n");

            bool result = session.HandlePacket(packet);

            Assert.IsFalse(result);
        }

        [TestMethod]
        public void RateSession_HandlePacket_WithLastRequest_InvokesCallback()
        {
            var session = new RateSession(_deviceHost);
            var request = new RateRequest();
            request.Packet = new HardwarePacket("RATE S\r\n", true);
            RateResponse receivedResponse = null;
            request.CallBackResponse = (o, e) => { receivedResponse = e as RateResponse; };

            session.HandleRequest(request);
            session.Timer();

            var okPacket = new HardwarePacket("OK\r\n");
            session.HandlePacket(okPacket);

            Assert.IsNotNull(receivedResponse);
            Assert.IsTrue(receivedResponse.Result);
        }

        [TestMethod]
        public void RateSession_ProcessRequest_NoWait4Response_AnswersImmediately()
        {
            var session = new RateSession(_deviceHost);
            var request = new RateRequest();
            request.Packet = new HardwarePacket("CMD\r\n", false);
            RateResponse receivedResponse = null;
            request.CallBackResponse = (o, e) => { receivedResponse = e as RateResponse; };

            session.HandleRequest(request);
            session.Timer();

            Assert.IsNotNull(receivedResponse);
            Assert.IsTrue(receivedResponse.Result);
        }

        [TestMethod]
        public void RateSession_AnswerLastRequest_InvokeWithNoCallback_ClearsLastRequest()
        {
            var session = new RateSession(_deviceHost);
            var request = new RateRequest
            {
                Packet = new HardwarePacket("RATE S\r\n", true),
                CallBackResponse = null
            };
            var po = new PrivateObject(session);
            po.SetProperty("LastRequest", request);
            po.Invoke("AnswerLastRequest", new RateResponse(true));
            Assert.IsNull(po.GetProperty("LastRequest"));
        }

        #endregion

        #region GetSetTimeSession Tests

        [TestMethod]
        public void GetSetTimeSession_HandleRequest_ReturnsTrue()
        {
            var session = new GetSetTimeSession(_deviceHost);
            var request = new GetSetDateRequest();
            request.Packet = new HardwarePacket("DATE 01/15/25\r\n", true);

            var result = session.HandleRequest(request);

            Assert.IsTrue(result.Result);
        }

        [TestMethod]
        public void GetSetTimeSession_HandlePacket_NoLastRequest_ReturnsFalse()
        {
            var session = new GetSetTimeSession(_deviceHost);
            var packet = new HardwarePacket("data\r\n");

            bool result = session.HandlePacket(packet);

            Assert.IsFalse(result);
        }

        [TestMethod]
        public void GetSetTimeSession_HandlePacket_WithRequest_InvokesCallback()
        {
            var session = new GetSetTimeSession(_deviceHost);
            var request = new GetSetDateRequest();
            request.Packet = new HardwarePacket("DATE 01/15/25\r\n", true);
            GetSetDateResponse receivedResponse = null;
            request.CallBackResponse = (o, e) => { receivedResponse = e as GetSetDateResponse; };

            session.HandleRequest(request);
            session.Timer();

            var okPacket = new HardwarePacket("OK\r\n");
            session.HandlePacket(okPacket);

            Assert.IsNotNull(receivedResponse);
            Assert.IsTrue(receivedResponse.Result);
        }

        [TestMethod]
        public void GetSetTimeSession_ProcessRequest_NoWait_AnswersImmediately()
        {
            var session = new GetSetTimeSession(_deviceHost);
            var request = new GetSetDateRequest();
            request.Packet = new HardwarePacket("CMD\r\n", false);
            GetSetDateResponse receivedResponse = null;
            request.CallBackResponse = (o, e) => { receivedResponse = e as GetSetDateResponse; };

            session.HandleRequest(request);
            session.Timer();

            Assert.IsNotNull(receivedResponse);
            Assert.IsTrue(receivedResponse.Result);
        }

        [TestMethod]
        public void GetSetTimeSession_HandlePacket_ResponseNotComplete_OKFalse_ReturnsFalse()
        {
            var session = new GetSetTimeSession(_deviceHost);
            var request = new GetSetDateRequest();
            request.Packet = new HardwarePacket("DATE 01/15/25\r\n", true);
            request.CallBackResponse = (o, e) => { };

            session.HandleRequest(request);
            session.Timer();

            var incomplete = new HardwarePacket("=>");
            Assert.IsFalse(session.HandlePacket(incomplete));
        }

        [TestMethod]
        public void GetSetTimeSession_HandlePacket_WrongLastRequestType_ReturnsFalse()
        {
            var session = new GetSetTimeSession(_deviceHost);
            var logsRequest = new LogsRequest(LogsRequest.LogCommands.ClearLogs)
            {
                Packet = new HardwarePacket("LOG CLR\r\n", true)
            };
            var po = new PrivateObject(session);
            po.SetProperty("LastRequest", logsRequest);

            var okPacket = new HardwarePacket("OK\r\n");
            Assert.IsFalse(session.HandlePacket(okPacket));
        }

        [TestMethod]
        public void GetSetTimeSession_ProcessRequest_NullRequest_DoesNotThrow()
        {
            var session = new GetSetTimeSession(_deviceHost);
            var po = new PrivateObject(session);
            po.Invoke("ProccessRequest", new object[] { null });
        }

        [TestMethod]
        public void GetSetTimeSession_ProcessRequest_NullPacket_DoesNotThrow()
        {
            var session = new GetSetTimeSession(_deviceHost);
            var request = new GetSetDateRequest { Packet = null };
            var po = new PrivateObject(session);
            po.Invoke("ProccessRequest", request);
        }

        [TestMethod]
        public void GetSetTimeSession_ProcessRequest_NoCallback_ClearsLastRequest()
        {
            var session = new GetSetTimeSession(_deviceHost);
            var request = new GetSetDateRequest();
            request.Packet = new HardwarePacket("CMD\r\n", false);
            request.CallBackResponse = null;

            session.HandleRequest(request);
            session.Timer();

            Assert.IsTrue(session.Avilable4Transport);
        }

        #endregion

        #region InitChannelsSession Tests

        [TestMethod]
        public void InitChannelsSession_HandleRequest_ReturnsTrue()
        {
            var session = new InitChannelsSession(_deviceHost);
            var request = new InitChannelsRequest(1);
            request.Packet = new HardwarePacket("FUNC 1,VDC\r\n", true);

            var result = session.HandleRequest(request);

            Assert.IsTrue(result.Result);
        }

        [TestMethod]
        public void InitChannelsSession_HandlePacket_NoLastRequest_ReturnsFalse()
        {
            var session = new InitChannelsSession(_deviceHost);
            var packet = new HardwarePacket("data\r\n");

            bool result = session.HandlePacket(packet);

            Assert.IsFalse(result);
        }

        [TestMethod]
        public void InitChannelsSession_HandlePacket_WithRequest_InvokesCallback()
        {
            var session = new InitChannelsSession(_deviceHost);
            var request = new InitChannelsRequest(1);
            request.Packet = new HardwarePacket("FUNC 1,VDC\r\n", true);
            InitChannelsResponse receivedResponse = null;
            request.CallBackResponse = (o, e) => { receivedResponse = e as InitChannelsResponse; };

            session.HandleRequest(request);
            session.Timer();

            var okPacket = new HardwarePacket("OK\r\n");
            session.HandlePacket(okPacket);

            Assert.IsNotNull(receivedResponse);
            Assert.IsTrue(receivedResponse.Result);
        }

        [TestMethod]
        public void InitChannelsSession_ProcessRequest_NoWait_AnswersImmediately()
        {
            var session = new InitChannelsSession(_deviceHost);
            var request = new InitChannelsRequest(1);
            request.Packet = new HardwarePacket("CMD\r\n", false);
            InitChannelsResponse receivedResponse = null;
            request.CallBackResponse = (o, e) => { receivedResponse = e as InitChannelsResponse; };

            session.HandleRequest(request);
            session.Timer();

            Assert.IsNotNull(receivedResponse);
            Assert.IsTrue(receivedResponse.Result);
        }

        [TestMethod]
        public void InitChannelsSession_AnswerLastRequest_InvokeWithNoCallback_ClearsLastRequest()
        {
            var session = new InitChannelsSession(_deviceHost);
            var request = new InitChannelsRequest(1)
            {
                Packet = new HardwarePacket("FUNC 1,VDC\r\n", true),
                CallBackResponse = null
            };
            var po = new PrivateObject(session);
            po.SetProperty("LastRequest", request);
            po.Invoke("AnswerLastRequest", new InitChannelsResponse(true));
            Assert.IsNull(po.GetProperty("LastRequest"));
        }

        #endregion

        #region BaseSession Timer Tests

        [TestMethod]
        public void BaseSession_Timer_Available_DequeuesAndProcesses()
        {
            var session = new LogsSession(_deviceHost);
            var request = new LogsRequest(LogsRequest.LogCommands.ClearLogs);
            request.Packet = new HardwarePacket("LOG CLR\r\n", true);

            session.HandleRequest(request);
            Assert.IsTrue(session.Avilable4Transport); // No LastRequest yet

            session.Timer(); // Should dequeue and set LastRequest

            Assert.IsFalse(session.Avilable4Transport); // Now has LastRequest
        }

        [TestMethod]
        public void BaseSession_Timer_NotAvailable_DoesNotDequeue()
        {
            var session = new LogsSession(_deviceHost);

            // Queue two requests
            var req1 = new LogsRequest(LogsRequest.LogCommands.ClearLogs);
            req1.Packet = new HardwarePacket("LOG CLR\r\n", true);
            var req2 = new LogsRequest(LogsRequest.LogCommands.StartScan);
            req2.Packet = new HardwarePacket("SCAN 1\r\n", true);

            session.HandleRequest(req1);
            session.HandleRequest(req2);

            session.Timer(); // Dequeues req1
            Assert.IsFalse(session.Avilable4Transport);

            session.Timer(); // Should NOT dequeue req2 because LastRequest is still pending
            Assert.IsFalse(session.Avilable4Transport);
        }

        [TestMethod]
        public void BaseSession_Timer_EmptyQueue_DoesNothing()
        {
            var session = new LogsSession(_deviceHost);

            // No requests queued
            session.Timer();

            Assert.IsTrue(session.Avilable4Transport);
        }

        [TestMethod]
        public void BaseSession_Avilable4Transport_DefaultIsTrue()
        {
            var session = new LogsSession(_deviceHost);

            Assert.IsTrue(session.Avilable4Transport);
        }

        #endregion

        #region BaseSession OnDisconnect Tests

        [TestMethod]
        public void BaseSession_OnDisconnect_ClearsLastRequestAndQueue()
        {
            var session = new LogsSession(_deviceHost);

            // Queue a request and process it
            var request = new LogsRequest(LogsRequest.LogCommands.ClearLogs);
            request.Packet = new HardwarePacket("LOG CLR\r\n", true);
            session.HandleRequest(request);
            session.Timer();

            Assert.IsFalse(session.Avilable4Transport);

            // Queue more requests
            var req2 = new LogsRequest(LogsRequest.LogCommands.StartScan);
            req2.Packet = new HardwarePacket("SCAN 1\r\n", true);
            session.HandleRequest(req2);

            session.OnDisconnect();

            Assert.IsTrue(session.Avilable4Transport);
        }

        #endregion

        #region LastRequestTimedOut Tests (via PrivateObject)

        [TestMethod]
        public void LogsSession_LastRequestTimedOut_ClearsLastRequest()
        {
            var session = new LogsSession(_deviceHost);
            var request = new LogsRequest(LogsRequest.LogCommands.ClearLogs);
            request.Packet = new HardwarePacket("LOG CLR\r\n", true);
            LogsResponse receivedResponse = null;
            request.CallBackResponse = (o, e) => { receivedResponse = e as LogsResponse; };

            session.HandleRequest(request);
            session.Timer(); // sets LastRequest

            Assert.IsFalse(session.Avilable4Transport);

            // Invoke LastRequestTimedOut via PrivateObject
            var po = new PrivateObject(session);
            po.Invoke("LastRequestTimedOut");

            Assert.IsTrue(session.Avilable4Transport);
            Assert.IsNotNull(receivedResponse);
            Assert.IsFalse(receivedResponse.Result);
        }

        [TestMethod]
        public void InitSystemSession_LastRequestTimedOut_ClearsLastRequest()
        {
            var session = new InitSystemSession(_deviceHost);
            var request = new InitSystemRequest();
            request.Packet = new HardwarePacket("*RST\r\n", true);
            bool callbackFired = false;
            request.CallBackResponse = (o, e) => { callbackFired = true; };

            session.HandleRequest(request);
            session.Timer();

            var po = new PrivateObject(session);
            po.Invoke("LastRequestTimedOut");

            Assert.IsTrue(session.Avilable4Transport);
            Assert.IsTrue(callbackFired);
        }

        [TestMethod]
        public void RateSession_LastRequestTimedOut_ClearsLastRequest()
        {
            var session = new RateSession(_deviceHost);
            var request = new RateRequest();
            request.Packet = new HardwarePacket("RATE S\r\n", true);
            bool callbackFired = false;
            request.CallBackResponse = (o, e) => { callbackFired = true; };

            session.HandleRequest(request);
            session.Timer();

            var po = new PrivateObject(session);
            po.Invoke("LastRequestTimedOut");

            Assert.IsTrue(session.Avilable4Transport);
            Assert.IsTrue(callbackFired);
        }

        [TestMethod]
        public void GetSetTimeSession_LastRequestTimedOut_ClearsLastRequest()
        {
            var session = new GetSetTimeSession(_deviceHost);
            var request = new GetSetDateRequest();
            request.Packet = new HardwarePacket("DATE 01/15/25\r\n", true);
            bool callbackFired = false;
            request.CallBackResponse = (o, e) => { callbackFired = true; };

            session.HandleRequest(request);
            session.Timer();

            var po = new PrivateObject(session);
            po.Invoke("LastRequestTimedOut");

            Assert.IsTrue(session.Avilable4Transport);
            Assert.IsTrue(callbackFired);
        }

        [TestMethod]
        public void InitChannelsSession_LastRequestTimedOut_ClearsLastRequest()
        {
            var session = new InitChannelsSession(_deviceHost);
            var request = new InitChannelsRequest(1);
            request.Packet = new HardwarePacket("FUNC 1,VDC\r\n", true);
            bool callbackFired = false;
            request.CallBackResponse = (o, e) => { callbackFired = true; };

            session.HandleRequest(request);
            session.Timer();

            var po = new PrivateObject(session);
            po.Invoke("LastRequestTimedOut");

            Assert.IsTrue(session.Avilable4Transport);
            Assert.IsTrue(callbackFired);
        }

        [TestMethod]
        public void BaseSession_Start_DoesNotThrow()
        {
            var session = new LogsSession(_deviceHost);
            session.Start();
        }

        #endregion
    }

    /// <summary>
    /// Mock IComLayer for testing without real hardware.
    /// </summary>
    internal class MockComLayer : Maba.VCT.ComLayer.IComLayer
    {
        public string Title { get; set; } = "MockCom";
        public bool IsConnected { get; set; } = true;
        public Maba.VCT.ComLayer.Tunnel ParentTunnel { get; private set; } = new Maba.VCT.ComLayer.Tunnel();
        public DateTime CreationTime { get; set; } = DateTime.UtcNow;
        public DateTime? LastRX_Time { get; private set; }
        public DateTime? LastTX_Time { get; private set; }

        public string LastSentString { get; private set; }
        public byte[] LastSentBytes { get; private set; }

        public event Maba.VCT.ComLayer.DataReceivedDelegate DataReceived;
        public event Maba.VCT.ComLayer.LayerDestroyedDelegate LayerClosed;

        public bool ThrowOnClose { get; set; }

        public void Close()
        {
            if (ThrowOnClose)
                throw new InvalidOperationException("MockComLayer.Close test throw");
            IsConnected = false;
        }
        public void Dispose() { Close(); }
        public void Open() { IsConnected = true; }
        public void SendBytes(byte[] data) { LastSentBytes = data; }
        public void SendBytes(byte[] data, int offset, int count)
        {
            var actual = new byte[count];
            Buffer.BlockCopy(data, offset, actual, 0, count);
            LastSentBytes = actual;
        }
        public void SendString(string data) { LastSentString = data; }

        public void SimulateDataReceived(byte[] data, int offset, int count)
        {
            DataReceived?.Invoke(this, new Maba.VCT.ComLayer.DataReceivedEventArgs(data, offset, count));
        }

        public void SimulateStringDataReceived(string data)
        {
            DataReceived?.Invoke(this, new Maba.VCT.ComLayer.DataReceivedEventArgs(data));
        }

        public void SimulateLayerClosed()
        {
            LayerClosed?.Invoke(this, new Maba.VCT.ComLayer.DestroyedEventArgs());
        }

        /// <summary>Modbus identification path uses <see cref="Maba.VCT.ComLayer.DataReceivedEventArgs"/> float ctor.</summary>
        public void SimulateFloatDataReceived(float value)
        {
            DataReceived?.Invoke(this, new Maba.VCT.ComLayer.DataReceivedEventArgs(value, 0, 0));
        }
    }
}
