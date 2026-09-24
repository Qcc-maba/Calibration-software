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
            var parts = SplitFields(MessageData);
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

            /*  "Email" is read here rather than in each of the four parsers: it may ride on any
                message type, the parsers each name their local message differently, and reading it
                once means a new message type gets it for free. Absent field -> nothing changes. */
            if (baseMessage != null)
            {
                baseMessage.Email = ExtractField("Email");
            }

            OnPacket(this, new PacketEventArgs(baseMessage));
        }


        #endregion

        #region Private Methods

        /// <summary>
        /// Splits a message into top-level fields, treating a comma inside a double-quoted value as
        /// part of that value rather than a field separator. MBA-970: a plain Split(',') chopped
        /// BatchChannels:"1,3,5,11,15" into "BatchChannels:\"1", "3", "5", "11", "15\"" - only the
        /// first token still had a ':' and survived, so every channel past the first was silently
        /// dropped with no error anywhere.
        /// </summary>
        private static List<string> SplitFields(string message)
        {
            var fields = new List<string>();
            if (string.IsNullOrEmpty(message))
            {
                return fields;
            }

            var start = 0;
            var inQuotes = false;
            for (var i = 0; i < message.Length; i++)
            {
                var c = message[i];
                if (c == '"')
                {
                    inQuotes = !inQuotes;
                }
                else if (c == ',' && !inQuotes)
                {
                    fields.Add(message.Substring(start, i - start).Trim());
                    start = i + 1;
                }
            }
            fields.Add(message.Substring(start).Trim());

            return fields.Where(f => f.Length > 0).ToList();
        }

        /// <summary>
        /// Reads one "Key":"Value" pair out of the raw message, for fields that are not specific to
        /// a single message type. Returns null when the field is absent.
        /// </summary>
        private string ExtractField(string fieldName)
        {
            if (string.IsNullOrEmpty(MessageData))
            {
                return null;
            }

            var parts = SplitFields(MessageData);

            foreach (var part in parts)
            {
                if (!part.Contains(":"))
                {
                    continue;
                }

                var keyValue = part.Split(new[] { ':' }, 2);
                var key = keyValue[0].Trim().Replace("\"", "").Replace("{", "").Trim();

                if (string.Equals(key, fieldName, StringComparison.OrdinalIgnoreCase))
                {
                    var value = keyValue[1].Trim().Replace("\"", "").Replace("}", "").Trim();
                    return string.IsNullOrWhiteSpace(value) ? null : value;
                }
            }

            return null;
        }

        private BaseMessage CreateReportParser()
        {
            var currentConfig = new CreateReportMessage();

            // Split the string by commas
            var parts = SplitFields(MessageData);

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
            var parts = SplitFields(MessageData);

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
            var parts = SplitFields(MessageData);

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
            var parts = SplitFields(MessageData);
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
