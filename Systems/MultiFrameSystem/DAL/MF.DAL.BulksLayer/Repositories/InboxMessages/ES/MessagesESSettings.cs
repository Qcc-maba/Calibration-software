using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Connectors.ElasticsearchLibrary;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.InboxMessages.ES
{
    public class MessagesESSettings : ElasticSettings
    {
        public string Index_Main_Name { get; set; } = "messages_dwh";


        public MessagesESSettings() : base()
        {
        }
    }
}
