using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.IO;
using Maba.Connectors.JsonHelpersLibrary.HierarchyFiles;

namespace Maba.Connectors.JsonHelpersLibrary.Test
{
    [TestClass]
    public class JsonHelpersLibrary_FilesLocatorTest
    {
        #region members

        private string _FolderName = "PPSettingsPP";
        private string _FileName = "PPTest1PP";

        private string path = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
        private int MaxStep = 4;

        #endregion

        #region private methods

        private void deleteFolders()
        {
            var p = path;
            for (int i = 0; i < MaxStep; i++)
            {
                if (Directory.Exists(Path.Combine(p, _FolderName)))
                {
                    Directory.Delete(Path.Combine(p, _FolderName), true);
                }

                p = Path.GetDirectoryName(p);
            }
        }

        #endregion

        [TestInitialize]
        public void Init()
        {
            deleteFolders();
        }

        [TestMethod]
        public void FindNone()
        {
            Assert.IsNull(FilesLocator.Read<TestClasses.TypeA>(_FileName, CreateDefaultIfMissing: false, FolderName: _FolderName));
        }

        [TestMethod]
        public void FindLocal1()
        {
            var a_value2 = FilesLocator.Read<TestClasses.TypeA>(_FileName, FolderName: _FolderName);
            Assert.IsNotNull(a_value2);
        }

        [TestMethod]
        public void FindLocal2()
        {
            var test_a = new TestClasses.TypeA()
            {
                Test_Name = "test1234",
                TestNumber = 112233
            };

            //save
            FilesLocator.Write<TestClasses.TypeA>(path, _FolderName, _FileName, test_a);

            var a_value2 = FilesLocator.Read<TestClasses.TypeA>(_FileName, FolderName: _FolderName);
            Assert.IsNotNull(a_value2);
        }

        [TestMethod]
        public void FindUp1()
        {
            var test_a = new TestClasses.TypeA()
            {
                Test_Name = "test1234",
                TestNumber = 112233
            };

            //save
            FilesLocator.Write<TestClasses.TypeA>(path, _FolderName, _FileName, test_a, Step: 1);

            var a_value2 = FilesLocator.Read<TestClasses.TypeA>(_FileName, FolderName: _FolderName);
            Assert.IsNotNull(a_value2);
        }

        [TestMethod]
        public void FindUpX()
        {
            var test_a = new TestClasses.TypeA()
            {
                Test_Name = "test1234",
                TestNumber = 112233
            };

            for (int i = 0; i < MaxStep; i++)
            {
                //save
                FilesLocator.Write<TestClasses.TypeA>(path, _FolderName, _FileName, test_a, Step: i);

                //make sure not exsits local
                if (i > 0)
                {
                    Assert.IsNull(FilesLocator.Read<TestClasses.TypeA>(_FileName, maxStep: i - 1, CreateDefaultIfMissing: false, FolderName: _FolderName));
                }

                var a_value2 = FilesLocator.Read<TestClasses.TypeA>(_FileName, FolderName: _FolderName);
                Assert.IsNotNull(a_value2);

                deleteFolders();

            }
        }


        [TestMethod]
        public void TestCache()
        {
            var test_a = new TestClasses.TypeA()
            {
                Test_Name = "test1234",
                TestNumber = 112233
            };

            //save
            FilesLocator.Write<TestClasses.TypeA>(path, _FolderName, _FileName, test_a);

            //should be found
            var a_value1 = FilesLocator.Read<TestClasses.TypeA>(_FileName, FolderName: _FolderName);
            Assert.IsNotNull(a_value1);
            Assert.AreEqual(a_value1.Test_Name, test_a.Test_Name);
            Assert.AreEqual(a_value1.TestNumber, test_a.TestNumber);

            deleteFolders();

            //should be located in cache
            var a_value2 = FilesLocator.Read<TestClasses.TypeA>(_FileName, FolderName: _FolderName, CreateDefaultIfMissing: false);
            Assert.IsNotNull(a_value2);
            Assert.AreEqual(a_value2.Test_Name, test_a.Test_Name);
            Assert.AreEqual(a_value2.TestNumber, test_a.TestNumber);

            //clear cache improperly, still should  be found
            FilesLocator.ClearCache("f");
            var a_value3 = FilesLocator.Read<TestClasses.TypeA>(_FileName, FolderName: _FolderName, CreateDefaultIfMissing: false);
            Assert.IsNotNull(a_value3);
            Assert.AreEqual(a_value3.Test_Name, test_a.Test_Name);
            Assert.AreEqual(a_value3.TestNumber, test_a.TestNumber);

            //clear cache, should not be found
            FilesLocator.ClearCache();
            var a_value4 = FilesLocator.Read<TestClasses.TypeA>(_FileName, FolderName: _FolderName, CreateDefaultIfMissing: false);
            Assert.IsNull(a_value4);
        }
    }
}
