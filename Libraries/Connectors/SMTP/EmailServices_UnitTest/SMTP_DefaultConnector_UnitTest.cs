using System;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections.Generic;
using System.Threading;

namespace Maba.Connectors.EmailServices.Tests
{
    [TestClass]
    public class SMTP_DefaultConnector_UnitTest : BaseUnitTest
    {
        #region ctor

        public SMTP_DefaultConnector_UnitTest()
            : base()
        {
        }

        #endregion

        #region Test Methods

        [TestInitialize]
        public void Init()
        {
            init();
        }

        [TestMethod]
        public void SendFewMails_Async()
        {
            var time = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss");

            SendFewMails("Async_" + time, (message, connector) =>
            {
                var task = connector.SendAsync(message);
            });
        }

        [TestMethod]
        public void SendFewMails_Synchronized()
        {
            var time = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss");

            SendFewMails("Synchronized_" + time, (message, connector) =>
            {
                var result = connector.Send(message);
            });
        }

        #endregion
    }
}
