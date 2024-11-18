using Maba.AccountSystem.AspNetIdentity.Identity2.DAL;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AspNetIdentity2.Test.DAL
{
    [TestClass]
    public class temp
    {
        private const int TIME_OUT = 100000;

        private IdentityStore_SQL _CreateConnector()
        {
            var connection = new IdentityStore_SQL();

            return connection;
        }
        private T Wait<T>(Task<T> t)
        {
            Assert.IsTrue(t.Wait(TIME_OUT));

            return t.Result;
        }

        public temp()
        {
            var connector2 = _CreateConnector();

            for (int i = 0; i < 0; i++)
            {
                var TimeZones = Wait(connector2.GetSystemTimeZonesAsync()).ToArray();
                Assert.AreEqual(104, TimeZones.Length);
                Assert.IsTrue(TimeZones.All(t => t.DaylightName != null));

                var TemperatureUnits = Wait(connector2.GetSystemTemperatureUnitsAsync()).ToArray();
                Assert.AreEqual(2, TemperatureUnits.Length);
                Assert.IsTrue(TemperatureUnits.All(t => t.DisplayUnit != null));


                var SystemUIFormats = Wait(connector2.GetUIFormatsAsync()).ToArray();
                Assert.AreEqual(3, SystemUIFormats.Length);
                Assert.IsTrue(SystemUIFormats.All(t => t.CultureCode != null));

                var Roles = Wait(connector2.System_Role_GetAll(null)).ToArray();
                Assert.AreEqual(5, Roles.Length);
                Assert.IsTrue(Roles.All(t => t.Name != null));
            }
        }

        [TestInitialize]
        public void initMethod()
        {
            for (int i = 0; i < 0; i++)
            {
                var connector2 = _CreateConnector();

                var TimeZones = Wait(connector2.GetSystemTimeZonesAsync()).ToArray();
                Assert.AreEqual(104, TimeZones.Length);
                Assert.IsTrue(TimeZones.All(t => t.DaylightName != null));

                var TemperatureUnits = Wait(connector2.GetSystemTemperatureUnitsAsync()).ToArray();
                Assert.AreEqual(2, TemperatureUnits.Length);
                Assert.IsTrue(TemperatureUnits.All(t => t.DisplayUnit != null));


                var SystemUIFormats = Wait(connector2.GetUIFormatsAsync()).ToArray();
                Assert.AreEqual(3, SystemUIFormats.Length);
                Assert.IsTrue(SystemUIFormats.All(t => t.CultureCode != null));

                var Roles = Wait(connector2.System_Role_GetAll(null)).ToArray();
                Assert.AreEqual(5, Roles.Length);
                Assert.IsTrue(Roles.All(t => t.Name != null));
            }
        }

        //[TestMethod]
        //public void gg1()
        //{
            
        //}
        //[TestMethod]
        //public void gg2()
        //{

        //}
        //[TestMethod]
        //public void gg3()
        //{

        //}
        //[TestMethod]
        //public void gg4()
        //{

        //}
    }
}
