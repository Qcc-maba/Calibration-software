using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
//using System.Threading.Tasks.Dataflow;

namespace Maba.Connectors.SMSServices.Connectors
{
    public class NexmoClientConnector : ISMSSenderConnector
    {
        /**************************************************************************************
            Website     ::  https://www.nexmo.com/
            API         ::  https://docs.nexmo.com/messaging/sms-api
            Pricing     ::  Depends on target country.
	                        Examples: Israel 0.0104EUR, USA 0.0057EUR, UK 0.0333EUR
        
            ---------------------------------------------

            User        ::  aw@Maba.co.il
            Password    ::  Go_12345_Go

            API Key     ::  2d593260
            API Secret  ::  b19791b1

        **************************************************************************************/


        #region CONSTANTS

        public const string CONNECTOR_TYPE = "NexmoClientConnector";

        #endregion

        #region properties

        public NexmoClientSettings Settings { get; set; }

        #endregion

        #region private methods

        private async Task<bool> _Send(SMSMessage message)
        {
            message.Status = ProccesStatues.Sending;

            try
            {
                string urlAddress = string.Format(Settings.CustomGatewayAddress ?? NexmoClientSettings.DefaultGatewayAddress,
                                  Settings.ApiKey,
                                  Settings.ApiSecret,
                                  message.Sender ?? Settings.BaseSettings.DefaultSenderName,
                                  message.Destination,
                                  message.Body);


                using (var client = new System.Net.WebClient())
                {
                    var jsonStr = await client.DownloadStringTaskAsync(urlAddress);
                    var json = JObject.Parse(jsonStr);// System.Text.Encoding.UTF8.GetString(buffer));

                    if (json["message-count"] == null)
                    {
                        throw new FormatException("The returend JSON format is invalid.");
                    }

                    var statusCode = json["messages"][0];
                    var tstatusCode = statusCode["status"];

                    if (tstatusCode.Value<string>() == "0")
                    {
                        message.Status = ProccesStatues.Sent;
                        if (SendingMessage != null)
                        {
                            SendingMessage.BeginInvoke(this, new SendingMessageEventArgs(message, true, DateTime.UtcNow), null, null);
                        }

                        return true;
                    }
                    else
                    {
                        message.Status = ProccesStatues.SendingFailed;
                        if (SendingMessage != null)
                        {
                            SendingMessage.BeginInvoke(this, new SendingMessageEventArgs(message, false, DateTime.UtcNow), null, null);
                        }

                        return false;
                    }
                }
            }

            catch
            {
                message.Status = ProccesStatues.SendingFailed;
                return false;
            }

        }

        #endregion

        #region ctor

        public NexmoClientConnector(SMSServiceSettings settings)
        {
            Settings = new NexmoClientSettings(settings);
        }

        #endregion

        #region ISMSSenderConnector members

        public event SendingMessageDelegate SendingMessage;

        public bool Send(SMSMessage message, int timeoutMilliseconds)
        {
            message.Status = ProccesStatues.Pending;
            message.PostedDate = DateTime.UtcNow;

            var task = _Send(message);
            return task.Wait(timeoutMilliseconds);
        }

        public async Task<bool> SendAsync(SMSMessage message)
        {
            message.Status = ProccesStatues.Pending;
            message.PostedDate = DateTime.UtcNow;

            return await _Send(message);
        }

        //public bool Send(SMSMessage message, int timeoutMilliseconds)
        //{
        //    message.PostedDate = DateTime.UtcNow;
        //    var task = _InternalBuffer.SendAsync(message);
        //    return task.Wait(timeoutMilliseconds);
        //}

        //public Task SendAsync(SMSMessage message)
        //{
        //    message.PostedDate = DateTime.UtcNow;

        //    return _InternalBuffer.SendAsync(message);
        //}

        #endregion
    }
}
