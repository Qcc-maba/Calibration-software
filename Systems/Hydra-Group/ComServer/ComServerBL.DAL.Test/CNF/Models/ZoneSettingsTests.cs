using Microsoft.VisualStudio.TestTools.UnitTesting;
using ComServerBL.Hydra2.DAL.CNF.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ComServerBL.Hydra2.DAL.CNF.Models.Test
{
    [TestClass()]
    public class ZoneSettingsTests
    {
        public long ConfigID { get; set; } = 1;

        [TestMethod()]
        public void ZoneSettings_Test()
        {
            using (var db = new CNFRepository())
            {
                var zones = db.GetZones(ConfigID);

                Assert.IsNotNull(zones);
                Assert.IsTrue(zones.Length > 0);
            }
        }
    }
}