using Maba.VCT.Common;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// The station's signed-in user. Whoever it names decides which loggers and which measurement
    /// channels get loaded from SQL, so the rules that matter are: a blank announcement never
    /// erases a known identity, and a genuine change is announced exactly once so settings are not
    /// reloaded on every heartbeat.
    /// </summary>
    [TestClass]
    public class CalibratorSessionTests
    {
        [TestInitialize]
        [TestCleanup]
        public void Reset()
        {
            CalibratorSession.Clear();
        }

        [TestMethod]
        public void SetEmail_FirstAnnouncement_IsAccepted()
        {
            Assert.IsTrue(CalibratorSession.SetEmail("eliran_ha@mba.co.il"));
            Assert.AreEqual("eliran_ha@mba.co.il", CalibratorSession.Email);
        }

        [TestMethod]
        public void SetEmail_IsTrimmed()
        {
            CalibratorSession.SetEmail("  tech@mba.co.il  ");
            Assert.AreEqual("tech@mba.co.il", CalibratorSession.Email);
        }

        [TestMethod]
        public void SetEmail_SameAddressAgain_IsNotAChange()
        {
            CalibratorSession.SetEmail("tech@mba.co.il");

            // every message from the app carries it; only a real change may reload settings
            Assert.IsFalse(CalibratorSession.SetEmail("tech@mba.co.il"));
            Assert.IsFalse(CalibratorSession.SetEmail("TECH@MBA.CO.IL"), "e-mail is case-insensitive");
        }

        [TestMethod]
        public void SetEmail_Blank_DoesNotClearAKnownIdentity()
        {
            CalibratorSession.SetEmail("tech@mba.co.il");

            Assert.IsFalse(CalibratorSession.SetEmail(null));
            Assert.IsFalse(CalibratorSession.SetEmail("   "));
            Assert.AreEqual("tech@mba.co.il", CalibratorSession.Email,
                "a message without the field must leave the signed-in user alone");
        }

        [TestMethod]
        public void EmailChanged_FiresOnceOnARealChange()
        {
            var announced = 0;
            string last = null;
            System.EventHandler<string> handler = (s, e) => { announced++; last = e; };

            CalibratorSession.EmailChanged += handler;
            try
            {
                CalibratorSession.SetEmail("first@mba.co.il");
                CalibratorSession.SetEmail("first@mba.co.il");   // repeat
                CalibratorSession.SetEmail("second@mba.co.il");  // a different technician

                Assert.AreEqual(2, announced);
                Assert.AreEqual("second@mba.co.il", last);
            }
            finally
            {
                CalibratorSession.EmailChanged -= handler;
            }
        }

        [TestMethod]
        public void Clear_ForgetsTheUser()
        {
            CalibratorSession.SetEmail("tech@mba.co.il");
            CalibratorSession.Clear();
            Assert.IsNull(CalibratorSession.Email);
        }
    }
}
