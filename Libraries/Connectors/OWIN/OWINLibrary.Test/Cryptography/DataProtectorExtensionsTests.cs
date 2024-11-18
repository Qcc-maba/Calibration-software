using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Connectors.OWINLibrary.Cryptography;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Security.Cryptography;
using Microsoft.Owin.Security.DataProtection;

namespace Maba.Connectors.OWINLibrary.Test.Cryptography
{
    [TestClass()]
    public class DataProtectorExtensionsTests
    {
        public IDataProtector _CreateDataProtector()
        {
            var settings = new Security.DataProtectionProviderSettings();
            var provider = settings.CreateDataProtectionProvider();

            return provider.Create();
        }

        [TestMethod()]
        public void ASCIIProtect_Test()
        {
            var d = _CreateDataProtector();

            string testedString = "test";

            var _protected = DataProtectorExtensions.ASCIIProtect(d, testedString);
            var _unprotected = DataProtectorExtensions.ASCIIUnprotect(d, _protected);
            Assert.AreEqual(_unprotected, testedString);
        }

        [TestMethod()]
        public void ASCIIUnprotect_Test()
        {
            //ASCIIProtect_Test
        }

        [TestMethod()]
        public void ObjectUnprotect_Test()
        {
            var d = _CreateDataProtector();

            var obj = new Class1()
            {
                ID = 123454,
                Name = "Name_" + Guid.NewGuid().ToString(),
                Street = "Street_" + Guid.NewGuid().ToString(),
            };

            var _protected = DataProtectorExtensions.ObjectProtect(d, obj);
            var _unprotected = DataProtectorExtensions.ObjectUnprotect<Class1>(d, _protected);
            Assert.IsNotNull(_unprotected);

            Assert.AreEqual(_unprotected.ID, obj.ID);
            Assert.AreEqual(_unprotected.Name, obj.Name);
            Assert.AreEqual(_unprotected.Street, obj.Street);
        }

        [TestMethod()]
        public void ObjectProtect_Test()
        {
            //ObjectUnprotect_Test
        }
    }
}