using System;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Threading;
using System.Collections.Generic;
using System.IO;
using System.Xml.Xsl;
using System.Net.Mail;

namespace Maba.Connectors.EmailServices.Tests
{
    [TestClass]
    public class EmailTemplatedTransform_UnitTest : BaseUnitTest
    {
        #region private members

        private string[] Templates = new string[] { "Array.xsl", "Simple.xsl", "http://www.mydomain.com/template.xsl" };

        #endregion

        #region ctor

        public EmailTemplatedTransform_UnitTest()
        {
        }

        #endregion

        #region private methods

        private MailTranformers.TestHost CreateData(int TemplateIndex)
        {
            var data = new MailTranformers.TestHost();

            var templateURI = Templates[TemplateIndex];
            if (templateURI.StartsWith("http"))
            {
                data.Template_filename = templateURI;
            }
            else
            {
                data.Template_filename = Path.Combine(Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location), "XSLTTemplates", templateURI);
            }

            data.Data = new MailTranformers.FormatObj()
            {
                Name = "My name",
                MyValue = new int[] { 11, 22, 33, 67, 99 },
                Project = new MailTranformers.ProjectClass() { Name = "Project112233Name" },
                Projects = Enumerable.Range(1, 10)
                    .Select(p => new MailTranformers.ProjectClass() { ID = p, Name = String.Format("Project_{0}", p) })
                    .ToArray()
            };

            data.Parameters = new MailTemplateTranformers.ParameterValue[]
            {
                    new MailTemplateTranformers.ParameterValue("UserName", "", "MyNameExample"),
                    new MailTemplateTranformers.ParameterValue("Link", "", "http://google.com/profile"),
                    new MailTemplateTranformers.ParameterValue("urn:FormatObj", new MailTranformers.FormatObj())
            };

            return data;
        }

        private void ValidateTranformData(MailTranformers.TestHost data, string finalTransformedData)
        {
            foreach (var p in data.Parameters.Where(pp => !String.IsNullOrEmpty(pp.Name)))
            {
                Assert.IsTrue(finalTransformedData.Contains(p.Value.ToString()));
            }
        }

        #endregion

        [TestMethod]
        public void XSLTTest_FileStream()
        {
            //prepare files and folders
            var outputTransformed_folder = Path.Combine(Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location),
                "XSLTTemplates",
                "Results");
            var processFiles_basicFilename = Path.Combine(outputTransformed_folder, "transformingProcess_");

            Directory.CreateDirectory(outputTransformed_folder);

            for (int i = 0; i < Templates.Length; i++)
            {
                var data = CreateData(i);

                //save input (for debugging reference)
                var inputfilename = processFiles_basicFilename + String.Format("{0}_input.xml", i);
                File.Delete(inputfilename);
                using (var sw = new StreamWriter(inputfilename))
                {
                    var xmlSer = new System.Xml.Serialization.XmlSerializer(data.Data.GetType());
                    xmlSer.Serialize(sw, data.Data);
                }

                //save the template (for debugging reference)
                var templateDebugCopy = processFiles_basicFilename + String.Format("{0}_output.xsl", i);
                if (data.Template_filename.StartsWith("http"))
                {
                    using (var wc = new System.Net.WebClient())
                    {
                        wc.DownloadFile(data.Template_filename, templateDebugCopy);
                    }
                }
                else
                {
                    File.Copy(data.Template_filename, templateDebugCopy, true);
                }

                //delete old output file
                var template_filename = processFiles_basicFilename + String.Format("{0}_output.txt", i);
                File.Delete(template_filename);

                //transform to stream
                using (var outputStream = new StreamWriter(template_filename, false))
                {
                    outputStream.AutoFlush = true;
                    var transformer = new MailTemplateTranformers.XsltMailTemplateTranformer();

                    var outputTransformed = transformer.Transform("Test",
                         data.Template_filename,
                         data.Data,
                         outputStream.BaseStream,
                         data.Parameters
                     );

                    outputTransformed.Wait();
                }

                //validate output file
                var allText = File.ReadAllText(template_filename);
                ValidateTranformData(data, allText);
            }
        }

        [TestMethod]
        public void XSLTTest_ToString()
        {
            for (int i = 0; i < Templates.Length; i++)
            {
                var data = CreateData(i);

                //transform to string
                var transformer = new MailTemplateTranformers.XsltMailTemplateTranformer();


                var outputTransformed = transformer.Transform("Test",
                    data.Template_filename,
                    data.Data,
                    data.Parameters
                );

                Assert.IsTrue(outputTransformed.Wait(20000));

                //validate output string
                ValidateTranformData(data, outputTransformed.Result);
            }
        }
    }
}


