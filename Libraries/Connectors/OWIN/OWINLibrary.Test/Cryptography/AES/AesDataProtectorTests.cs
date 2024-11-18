using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Connectors.OWINLibrary.Cryptography.AES;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;

namespace Maba.Connectors.OWINLibrary.Cryptography.AES.Test
{
    [TestClass()]
    public class AesDataProtectorTests
    {
        private int differePerecentPer100 = 5;
        private string[] keys;
        public AesDataProtectorTests()
        {
            keys = new string[] { null, "", "myKey", "123435", "mykkddssm" };
        }

        [TestMethod()]
        public void Protect_Test_randomBuffers()
        {
            var rand = new Random();

            foreach (var key in keys)
            {
                var p = new AesDataProtector(key);

                for (int lenIndex = 0; lenIndex < 30; lenIndex++)
                {
                    var data = new byte[1 + (20 * lenIndex)];
                    rand.NextBytes(data);

                    var protectedData = p.Protect(data);
                    Assert.IsNotNull(protectedData);
                        _CompareBuffers(protectedData, data, false);

                    var unprotectedData = p.Unprotect(protectedData);
                    Assert.IsNotNull(unprotectedData);

                    Assert.AreEqual(unprotectedData.Length, data.Length);
                    _CompareBuffers(unprotectedData, data, true);
                }
            }
        }

        private void _CompareBuffers(byte[] a, byte[] b, bool expectedResult)
        {
            var len = Math.Min(b.Length, a.Length);

            int count = 0;
            for (int i = 0; i < len; i++)
            {
                count += b[i] == a[i] ? 1 : 0;
            }

            if (expectedResult)
            {
                Assert.AreEqual(count, len);
                Assert.AreEqual(b.Length, len);
                Assert.AreEqual(a.Length, len);
            }
            else
            {
                var allowedEqual = Math.Min(len / 2m, differePerecentPer100 * (len / 100m));

                Assert.IsTrue(count <= allowedEqual);
            }
        }

        [TestMethod()]
        public void Protect_Test_fromFiles()
        {
            foreach (var key in keys)
            {
                var p = new AesDataProtector(key);

                var folder = Path.Combine(Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location),
                    "Cryptography", "AES", "Files");

                //load files
                var unprotectedData = File.ReadAllBytes(Path.Combine(folder, "unprotectedData.hex"));

                #region test unprotectedData -> protected -> unprotectedData
                {
                    //protect
                    var protectedData_proccess = p.Protect(unprotectedData);
                    Assert.IsNotNull(protectedData_proccess);
                    Assert.AreNotEqual(protectedData_proccess.Length, unprotectedData.Length);
                    _CompareBuffers(protectedData_proccess, unprotectedData, false);

                    //unprotected
                    var unprotectedData_proccess = p.Unprotect(protectedData_proccess);
                    Assert.IsNotNull(unprotectedData_proccess);
                    Assert.AreEqual(unprotectedData_proccess.Length, unprotectedData.Length);
                    _CompareBuffers(unprotectedData_proccess, unprotectedData, true);
                }
                #endregion
            }
        }

        [TestMethod()]
        public void Unprotect_Test()
        {
            //covered by Protect_Test
        }
    }
}