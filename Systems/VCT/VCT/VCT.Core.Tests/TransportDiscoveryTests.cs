using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.VCT.ComLayer;
using System.Linq;

namespace Maba.VCT.Core.Tests
{
    /// <summary>
    /// Covers the decisions <see cref="TransportDiscovery"/> makes without hardware: reading a GPIB
    /// address out of a VISA resource string, and telling a real identification reply from the noise a
    /// mismatched baud rate produces.
    /// </summary>
    [TestClass]
    public class TransportDiscoveryTests
    {
        #region GPIB address parsing

        [TestMethod]
        public void TryParseGpibAddress_ReadsRealResourceStrings()
        {
            int address;

            // The four addresses this bench has actually reported.
            Assert.IsTrue(TransportDiscovery.TryParseGpibAddress("GPIB0::3::INSTR", out address));
            Assert.AreEqual(3, address);

            Assert.IsTrue(TransportDiscovery.TryParseGpibAddress("GPIB0::4::INSTR", out address));
            Assert.AreEqual(4, address);

            Assert.IsTrue(TransportDiscovery.TryParseGpibAddress("GPIB0::7::INSTR", out address));
            Assert.AreEqual(7, address);

            Assert.IsTrue(TransportDiscovery.TryParseGpibAddress("GPIB1::18::INSTR", out address));
            Assert.AreEqual(18, address);
        }

        [TestMethod]
        public void TryParseGpibAddress_RejectsAnythingElse()
        {
            int address;

            Assert.IsFalse(TransportDiscovery.TryParseGpibAddress("USB0::0x2A8D::0x178B::CN1::INSTR", out address));
            Assert.IsFalse(TransportDiscovery.TryParseGpibAddress("ASRL10::INSTR", out address));
            Assert.IsFalse(TransportDiscovery.TryParseGpibAddress("GPIB0::INSTR", out address));
            Assert.IsFalse(TransportDiscovery.TryParseGpibAddress("", out address));
            Assert.IsFalse(TransportDiscovery.TryParseGpibAddress(null, out address));
        }

        [TestMethod]
        public void TryParseGpibAddress_RejectsAddressesOutsideTheBusRange()
        {
            // GPIB primary addresses are 0-30.
            int address;
            Assert.IsFalse(TransportDiscovery.TryParseGpibAddress("GPIB0::31::INSTR", out address));
            Assert.IsFalse(TransportDiscovery.TryParseGpibAddress("GPIB0::-1::INSTR", out address));
        }

        #endregion

        #region telling an identity from line noise

        [TestMethod]
        public void LooksLikeIdentification_AcceptsTheRealReplies()
        {
            // Every instrument brought up on this bench.
            Assert.IsTrue(TransportDiscovery.LooksLikeIdentification("FLUKE,5522A,1972905,1.1+1.3+1.8"));
            Assert.IsTrue(TransportDiscovery.LooksLikeIdentification("PRODIGIT_3111"));
            Assert.IsTrue(TransportDiscovery.LooksLikeIdentification("HEWLETT-PACKARD,53181A,0,3703"));
            Assert.IsTrue(TransportDiscovery.LooksLikeIdentification("PENDULUM, CNT-90, 938636, V1.14 28 Jun 2006"));
            Assert.IsTrue(TransportDiscovery.LooksLikeIdentification("Siglent Technologies,SDG6052X,SDG6XEBD4R0879,6.01.01.35R5B1"));
            Assert.IsTrue(TransportDiscovery.LooksLikeIdentification("KEYSIGHT TECHNOLOGIES,EDU-X 1002A,CN59280205,01.10"));
        }

        [TestMethod]
        public void LooksLikeIdentification_RejectsMismatchedBaudNoise()
        {
            // A wrong baud rate still returns bytes — high-bit rubbish and control codes. Accepting
            // those would pin an instrument to the wrong speed and it would never work again.
            Assert.IsFalse(TransportDiscovery.LooksLikeIdentification("øææþà"));
            Assert.IsFalse(TransportDiscovery.LooksLikeIdentification("\0\0\0\0\0\0"));
        }

        [TestMethod]
        public void LooksLikeIdentification_RejectsRepliesWithNoIdentityInThem()
        {
            // Digits or punctuation alone are a measurement or an echo, not an identity.
            Assert.IsFalse(TransportDiscovery.LooksLikeIdentification("0"));
            Assert.IsFalse(TransportDiscovery.LooksLikeIdentification("+0.0000"));
            Assert.IsFalse(TransportDiscovery.LooksLikeIdentification("123,456"));
            Assert.IsFalse(TransportDiscovery.LooksLikeIdentification(""));
            Assert.IsFalse(TransportDiscovery.LooksLikeIdentification("   "));
            Assert.IsFalse(TransportDiscovery.LooksLikeIdentification(null));
        }

        #endregion

        #region baud candidates

        [TestMethod]
        public void SerialBaudCandidates_CoverEverySpeedThisBenchUses()
        {
            var bauds = TransportDiscovery.SerialBaudCandidates;

            CollectionAssert.Contains(bauds, 9600);    // Fluke 5522A
            CollectionAssert.Contains(bauds, 115200);  // PRODIGIT 3111
            Assert.AreEqual(9600, bauds.First(), "the most common speed should be tried first");
            Assert.AreEqual(bauds.Length, bauds.Distinct().Count(), "no duplicate probe attempts");
        }

        #endregion
    }
}
