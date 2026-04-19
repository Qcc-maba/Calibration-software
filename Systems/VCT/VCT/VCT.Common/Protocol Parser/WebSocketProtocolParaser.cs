using Maba.VCT.Common.Protocol_Parser.WebSocketMessage;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;

namespace Maba.VCT.Common.Protocol_Parser
{
    public class WebSocketProtocolParaser : IProtocolParser
    {
        #region Members

        private string MessageData;

        #endregion

        #region IProtocol Events

        public PacketDelegate OnPacket { get; set; }


        #endregion
        
        #region IProtocol Methods

        public void OnData(byte[] buffer, int offset, int count)
        {

        }
        public void OnData(string data)
        {
            MessageData = data;
            ParsePackets();
        }

        public void ParsePackets()
        {
            BaseMessage baseMessage = null;
            var parts = MessageData.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                           .Select(p => p.Trim())
                           .ToList();
            var keyValue = parts[0].Split(new[] { ':' }, 2);
            var key = keyValue[0].Trim().Replace("\"", "");
            var value = keyValue[1].Trim().Replace("\"", "");
            if (value == "LoggerConfiguration")
            {
                baseMessage = LoggerConfigurationParser();
            }
            else if (value == "SensorsAssociation")
            {
                baseMessage = SensorsAssociationParser();
            }
            else if (value == "CreateReport")
            {
                baseMessage = CreateReportParser();
            }
            else if (value == "Status")
            {
                baseMessage = StatusParser();
            }
            OnPacket(this, new PacketEventArgs(baseMessage));
        }


        #endregion

        #region Private Methods

        private BaseMessage CreateReportParser()
        {
            var currentConfig = new CreateReportMessage();

            // Split the string by commas
            var parts = MessageData.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                           .Select(p => p.Trim())
                           .ToList();

            foreach (var part in parts)
            {
                // Parse key-value pairs
                if (part.Contains(":"))
                {
                    var keyValue = part.Split(new[] { ':' }, 2);
                    var key = keyValue[0].Trim().Replace("\"", "");
                    var value = keyValue[1].Trim().Replace("\"", "");

                    switch (key)
                    {
                        case "CMD":
                            // Skip the command as it's already known
                            break;
                    }
                }
            }
            return currentConfig;
        }

        public BaseMessage SensorsAssociationParser()
        {
            var currentConfig = new SensorsAssociationMessage();

            // Split the string by commas
            var parts = MessageData.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                           .Select(p => p.Trim())
                           .ToList();

            foreach (var part in parts)
            {
                // Parse key-value pairs
                if (part.Contains(":"))
                {
                    var keyValue = part.Split(new[] { ':' }, 2);
                    var key = keyValue[0].Trim().Replace("\"", "");
                    var value = keyValue[1].Trim().Replace("\"", "");
                    // Skip the "Logger Configuration" text as it's a separator
                    //if (value.Equals("SensorsAssociation", StringComparison.OrdinalIgnoreCase))
                    //{
                    //    if (currentConfig.LoggerId != null)  // If we have data, save the current configuration
                    //    {
                    //        currentConfig = new SensorsAssociationMessage();
                    //    }
                    //    continue;
                    //}
                    switch (key)
                    {
                        case "CMD":
                            // Skip the command as it's already known
                            break;
                        case "LoggerID":
                            currentConfig.LoggerId = value;
                            break;
                        case "DeviceID":
                            currentConfig.DeviceId = value;
                            break;
                        case "BatchID":
                            currentConfig.BatchId = value;
                            break;
                        case "BatchChannels":
                            currentConfig.BatchChannels = value;
                            break;
                        case "Units":
                            currentConfig.Units = value;
                            break;
                        case "Resolution":
                            currentConfig.Resolution = value;
                            break;
                        case "SendData":
                            currentConfig.SendData = bool.Parse(value);
                            break;
                    }
                }
            }
            return currentConfig;
        }

        public BaseMessage LoggerConfigurationParser()
        {
            var configurations = new LoggerConfigurationMessage
            {
                Loggers = new List<LoggerConfig>()
            };
            var currentConfig = new LoggerConfig();

            // Split the string by commas
            var parts = MessageData.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                           .Select(p => p.Trim())
                           .ToList();

            foreach (var part in parts)
            {
                // Parse key-value pairs
                if (part.Contains(":"))
                {
                    var keyValue = part.Split(new[] { ':' }, 2);
                    var key = keyValue[0].Trim().Replace("\"", "");
                    var value = keyValue[1].Trim().Replace("\"", "");
                    // Skip the "Logger Configuration" text as it's a separator
                    if (value.Equals("LoggerConfiguration", StringComparison.OrdinalIgnoreCase))
                    {
                        if (currentConfig.LoggerId != null)  // If we have data, save the current configuration
                        {
                            configurations.Loggers.Add(currentConfig);
                            currentConfig = new LoggerConfig();
                        }
                        continue;
                    }
                    switch (key)
                    {
                        case "CMD":
                            // Skip the command as it's already known
                            break;
                        case "LoggerID":
                            currentConfig.LoggerId = value;
                            break;
                        case "IP":
                            currentConfig.IP = value;
                            break;
                        case "Rate":
                            currentConfig.Rate = value;
                            break;
                        case "Interval":
                            currentConfig.Interval = value;
                            break;
                        case "BatchID":
                            currentConfig.BatchId = value;
                            break;
                        case "BatchChannels":
                            currentConfig.BatchChannels = value;
                            configurations.Loggers.Add(currentConfig);
                            currentConfig = new LoggerConfig();
                            break;
                    }
                }
            }
            return configurations;
        }

        private BaseMessage StatusParser()
        {
            var msg = new StatusMessage();
            var parts = MessageData.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                           .Select(p => p.Trim())
                           .ToList();
            foreach (var part in parts)
            {
                if (part.Contains(":"))
                {
                    var keyValue = part.Split(new[] { ':' }, 2);
                    var key = keyValue[0].Trim().Replace("\"", "");
                    var value = keyValue[1].Trim().Replace("\"", "");
                    switch (key)
                    {
                        case "Value":
                            msg.Value = value;
                            break;
                        case "DeviceID":
                            msg.DeviceID = value;
                            break;
                    }
                }
            }
            return msg;
        }

        public static string SerializeMessage<T>(T message) where T : BaseMessage
        {
            return JsonSerializer.Serialize(message, new JsonSerializerOptions
            {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            });
        }

        public static T ParseMessage<T>(string jsonMessage) where T : BaseMessage
        {
            return JsonSerializer.Deserialize<T>(jsonMessage, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
        }


        #endregion
    }
}
