using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using EmailServices = Maba.Connectors.EmailServices;

namespace Maba.Hydra2.Systems.MF.BL.Bulks.Base
{
    public class BLSettings
    {
        //public const string SETTING_LOCATOR_NAME = "MF#DAL#ViewModelLayerSettings";

        public DAL.AdminLayer.Repositories.RepositoryGenerator DAL_AdminLayer_RepositoriesGenerator { get; set; }
        public DAL.BulksLayer.Repositories.RepositoryGenerator DAL_BulksLayer_RepositoriesGenerator { get; set; }


        public Func<DAL.QueueingLayer.Queues.PendingWork.IDevicePendingWork> DAL_QueuesLayer_DevicePendingWork_Generator { get; set; }
        public Func<EmailServices.IEmailSenderConnector> Connectors_Emails_ServiceGenerator { get; set; }
    }
}
