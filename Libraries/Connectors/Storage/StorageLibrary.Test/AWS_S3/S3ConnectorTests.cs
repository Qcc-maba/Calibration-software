using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Connectors.StorageLibrary.AWS_S3;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;
using System.Net;

namespace Maba.Connectors.StorageLibrary.AWS_S3.Test
{
    [TestClass()]
    public class S3ConnectorTests
    {
        public const string BUCKET_TEST = "Maba-tests";

        #region private methods
        private T Wait<T>(Task<T> task)
        {
            Assert.IsTrue(task.Wait(20000));
            return task.Result;
        }
        private string[] _PrepareFiles(string folder, int filesCount, int filesize = 100)
        {
            var files = new List<String>();
            var fullpath = Path.Combine(
                Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location),
                "Files", folder);

            Directory.CreateDirectory(fullpath);

            for (int fileIndex = 0; fileIndex < filesCount; fileIndex++)
            {
                var filename = Path.Combine(fullpath, $"testfile{fileIndex}.txt");
                files.Add(filename);

                if (!File.Exists(filename))
                {
                    var line = "Probably the best connector in the world!!!";

                    using (var sw = new StreamWriter(filename))
                    {
                        for (int i = 0; i < filesize; i++)
                        {
                            sw.WriteLine(line);
                        }
                    }
                }
            }

            return files.ToArray();
        }

        private void _CompareFiles(string local, string s3Url)
        {
            var webClient = new WebClient();
            var file_s3 = webClient.DownloadData(s3Url);

            //get the local file
            var file_local = File.ReadAllBytes(local);
            Assert.AreEqual(file_s3.Length, file_local.Length);

            //validate data
            for (int i = 0; i < file_s3.Length; i++)
            {
                Assert.AreEqual(file_local[i], file_s3[i]);
            }
        }

        #endregion

        private IStorageConnector _CreateConnector()
        {
            var s3_settings = new S3Settings()
            {
                DefaultBucketName = BUCKET_TEST,
                AwsAccessKeyId = "AKIAI6TPJY6CUB7GBYXQ",
                AwsSecretAccessKey = "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",
                Region = "eu-west-1",
                DefaultFolder = "myFolder"
            };

            var baseS3 = new BaseS3Connector(s3_settings);
            var buckets = baseS3.ListAllBuckets();
            if (!buckets.Any(b => b == BUCKET_TEST))
            {
                Assert.IsTrue(baseS3.CreateBucket(BUCKET_TEST));
            }

            var s3 = new BaseS3Connector(s3_settings);

            return s3;
        }

        [TestMethod]
        public void UploadFile()
        {
            var connetor = _CreateConnector();

            var file = _PrepareFiles("testfileUpload", 1)[0];

            var request = new UploadRequest()
            {
                ContentType = "plain/txt",
                TargetPath = $"testFolder/testUploadFile_{DateTime.UtcNow.ToString("yyyyMMddHHmm")}_{Guid.NewGuid().ToString().Substring(0,6)}.txt",
                ACL = ACLControl.PublicRead
            };

            //upload
            var response = Wait(connetor.UploadFileAsync(file, request));


            //test uploading (get it back and compare)
            Assert.IsTrue(response.Result);
            _CompareFiles(file, response.ObjectFullUrl);

            //Testing method [DeleteObject]
            var deleteResult = Wait(connetor.DeleteFileAsync(request.TargetPath));
            Assert.IsTrue(deleteResult);

            var webClient = new WebClient();
            bool Failed = false;
            try
            {
                var file_s3 = webClient.DownloadData(response.ObjectFullUrl);
            }
            catch
            {
                Failed = true;
            }

            Assert.IsTrue(Failed);
        }

        [TestMethod]
        public void UploadFileStream()
        {
            var connetor = _CreateConnector();

            var file = _PrepareFiles("testfileUpload", 1)[0];

            UploadResponse response;
            var request = new UploadRequest()
            {
                ContentType = "plain/txt",
                TargetPath = $"testFolder/testUploadStream_{DateTime.UtcNow.ToString("yyyyMMddHHmm")}_{Guid.NewGuid().ToString().Substring(0, 6)}.txt",
                ACL = ACLControl.PublicRead
            };
            using (var fs = new FileStream(file, FileMode.Open))
            {
                response = Wait(connetor.UploadFileStreamAsync(fs, request));
            }

            Assert.IsTrue(response.Result);
            _CompareFiles(file, response.ObjectFullUrl);
        }

        [TestMethod]
        public void DeleteObject()
        {
            //covered by UploadFile
        }
    }
}