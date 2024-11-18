using System;
using System.Linq;

using Microsoft.VisualStudio.TestTools.UnitTesting;
using Microsoft.Owin.Hosting;
using Owin;
using System.Web.Http;
using System.Diagnostics;

namespace Maba.Connectors.HTTPLibrary.Test
{
    [TestClass]
    public class HTTPLibrary_Test
    {
        private const string uri = "http://localhost:5700";

        public HTTPLibrary_Test()
        {
        }

        #region private methods

        private void StartUp_Configuration(IAppBuilder app)
        {
            HttpConfiguration config = new HttpConfiguration();
            WebApplication.App_start.WebApiConfig.Register(config);

            app.UseWebApi(config);
        }

        private string GetServer(int num)
        {
            var serverUri = uri + num.ToString();
            WebApp.Start(serverUri, StartUp_Configuration);

            return serverUri;
        }

        private WebApplication.Models.Class1 BasicOperation(int num, string method, WebApplication.Models.Class1 data = null)
        {
            var serverUri = GetServer(num);

            var client = new HttpClient.HttpClientHelper();
            client.RequestHeaders = new System.Collections.Specialized.NameValueCollection();
            client.RequestHeaders.Add("MyHeader", "MyHeaderValue");
            client.RequestHeaders.Add("MyHeaderLong", "MyHeaderValue".PadRight(350, '#'));

            var r = new Random();

            var response = client.UploadData<WebApplication.Models.Class1, WebApplication.Models.Class1>(
                String.Format("{0}/api/Test/SendData/?x=1&y=2", serverUri),
                method,
                data);

            response.Wait();

            //tests
            Assert.IsNotNull(response.Result);
            Assert.IsNotNull(response.Result.Headers);
            Assert.IsTrue(response.Result.Headers.Length >= client.RequestHeaders.Count);
            Assert.IsNotNull(response.Result.Name);
            Assert.IsTrue(response.Result.ID > 0);

            Assert.AreEqual(response.Result.Method.ToLower(), method.ToLower());

            //test header sent
            foreach (string key in client.RequestHeaders)
            {
                var expectedValue = String.Format("{0}:{1}", key, client.RequestHeaders[key]);
                Assert.IsTrue(response.Result.Headers.Any(h => h == expectedValue));
            }

            return response.Result;
        }

        #endregion

        [TestMethod]
        public void TestMethod_Get()
        {
            var serverUri = GetServer(1);

            var client = new HttpClient.HttpClientHelper();
            client.RequestHeaders = new System.Collections.Specialized.NameValueCollection();
            client.RequestHeaders.Add("MyHeader", "MyHeaderValue");
            client.RequestHeaders.Add("MyHeaderLong", "MyHeaderValue".PadRight(350, '#'));

            var response = client.Get<WebApplication.Models.Class1>(String.Format("{0}/api/Test/Calc/?x=1&y=2", serverUri));

            response.Wait();

            //tests
            Assert.IsNotNull(response.Result);
            Assert.IsNotNull(response.Result.Headers);
            Assert.IsTrue(response.Result.Headers.Length >= client.RequestHeaders.Count);
            Assert.IsNotNull(response.Result.Name);
            Assert.IsTrue(response.Result.ID > 0);

            foreach (string key in client.RequestHeaders)
            {
                var expectedValue = String.Format("{0}:{1}", key, client.RequestHeaders[key]);
                Assert.IsTrue(response.Result.Headers.Any(h => h == expectedValue));
            }
        }

        [TestMethod]
        public void TestMethod_Post()
        {
            var r = new Random();
            var postedData = new WebApplication.Models.Class1()
            {
                ID = r.Next(0, 10000),
                Name = "Test Post Data",
                Headers = new string[] { "Header1", "Header2", "Header3" }
            };

            var response = BasicOperation(2, "POST", postedData);

            Assert.AreEqual(response.ID, postedData.ID);
            Assert.AreEqual(response.Name, postedData.Name);

            //test data sent
            foreach (string header in postedData.Headers)
            {
                Assert.IsTrue(response.Headers.Any(h => h == header));
            }
        }


        [TestMethod]
        public void TestMethod_Post_EmptyData()
        {
            BasicOperation(3, "POST", null);
        }

        [TestMethod]
        public void TestMethod_Delete()
        {
            var r = new Random();
            var postedData = new WebApplication.Models.Class1()
            {
                ID = r.Next(0, 10000),
                Name = "Test Post Data",
                Headers = new string[] { "Header1", "Header2", "Header3" }
            };

            var response = BasicOperation(4, "DELETE", postedData);

            Assert.AreEqual(response.ID, postedData.ID);
            Assert.AreEqual(response.Name, postedData.Name);

            //test data sent
            foreach (string header in postedData.Headers)
            {
                Assert.IsTrue(response.Headers.Any(h => h == header));
            }
        }

        [TestMethod]
        public void TestMethod_Delete_EmptyData()
        {
            BasicOperation(5, "DELETE", null);
        }

    }
}
