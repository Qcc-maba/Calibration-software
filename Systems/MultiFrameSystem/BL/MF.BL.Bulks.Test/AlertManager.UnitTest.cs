using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Connectors = Maba.Connectors;
using Maba.DAL.BaseDAL;

namespace Maba.Hydra2.Systems.MF.BL.Bulks.Test
{
    [TestClass]
    public class AlertManager_UnitTest
    {
        private Base.BLSettings managerSettings = null;

        public AlertManager_UnitTest()
        {
            //Emails
            var settings_emails = new Connectors.EmailServices.EmailServiceSettings()
            {
                EnableSsl = true,
                Credential_Password = "AhQas3G53vs/PXajQaZass0+r7goBbs6apSk6yenwsQJ",
                Credential_UserName = "AKIAJMSGJYPBHAKBJYPA",
                Timeout = 10000,
                Host = "email-smtp.us-east-1.amazonaws.com",
                Port = 25,
                UseDefaultCredentials = false,
                DefaultFromAddress = "aws@Maba.co.il"
            };

            #region Admin Repositories Generators

            var AdminLayer_RepositoryGenerator = new DAL.AdminLayer.Repositories.RepositoryGenerator()
            {
                Generator_IAccountRepository = () => new DAL.AdminLayer.Repositories.Account.TSQL.TSQLAccountRepository(BaseDALConnector.PROVIDER_NAME_MYSQL, ""),
                Generator_IDeviceRepository = () => new DAL.AdminLayer.Repositories.Device.TSQL.TSQLDeviceRepository(BaseDALConnector.PROVIDER_NAME_MYSQL, ""),
                //Generator_IDeviceDataReportingRepository = () => new DAL.AdminLayer.Repositories.Device.TSQL.TSQLIDeviceDataReportingRepository(BaseDALConnector.PROVIDER_NAME_MYSQL, ""),
                Generator_IDeviceProcessingRepository = () => new DAL.AdminLayer.Repositories.Device.TSQL.TSQLDeviceProcessingRepository(BaseDALConnector.PROVIDER_NAME_MYSQL, ""),
                Generator_IFolderingRepository = () => new DAL.AdminLayer.Repositories.Foldering.TSQL.TSQLFolderingRepository(BaseDALConnector.PROVIDER_NAME_MYSQL, ""),
               // Generator_IWeatherRepository = () => new DAL.AdminLayer.Repositories.Weather.TSQL.TSQLIWeatherRepository(BaseDALConnector.PROVIDER_NAME_MYSQL, "")
            };

            #endregion

            #region Admin Repositories Generators

            //var Elsatic settings

            var bulks_RepositoryGenerator = new DAL.BulksLayer.Repositories.RepositoryGenerator()
            {
                Generator_IInboxMessagesRepository = () => new DAL.BulksLayer.Repositories.InboxMessages.ES.ESInboxMessagesRepository(new DAL.BulksLayer.Repositories.InboxMessages.ES.MessagesESSettings()),
                Generator_IWeatherForecastsRepository = () => new DAL.BulksLayer.Repositories.Weather.ES.ESWeatherRepository(new DAL.BulksLayer.Repositories.Weather.ES.WeatherESSettings())
            };

            #endregion

            #region SQ

            var settings_sqs = new Connectors.AWS.SQS.SQSSettings()
            {
                QueueName = "HHS-SQS",
                AwsAccessKeyId = "AKIAIS2UJHGY4HV5VFPA",
                AwsSecretAccessKey = "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",
                Region = Amazon.RegionEndpoint.USWest1.SystemName,

                ReceiveMessage = new Connectors.AWS.SQS.ReceiveMessageSettings(),
                SendMessage = new Connectors.AWS.SQS.SendMessageSettings(),
            };

            #endregion

            managerSettings = new Base.BLSettings()
            {
                //Connectors_Emails_ServiceGenerator = () => new Connectors.EmailServices.Connectors.SMTPServerConnector(settings_emails),
                //DAL_AdminLayer_RepositoriesGenerator = AdminLayer_RepositoryGenerator,
                //DAL_BulksLayer_RepositoriesGenerator = bulks_RepositoryGenerator,
                //DAL_QueuesLayer_DevicePendingWork_Generator = () => new DAL.QueueingLayer.Queues.PendingWork.SQS.SQSDevicePendingWork(settings_sqs)
            };
        }
        [TestMethod]
        public void TestMethod1()
        {
            var manager = new Alerts.AlertsBLManager(managerSettings);

        }
    }
}
