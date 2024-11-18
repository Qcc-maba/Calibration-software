using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.Caching;
using System.Text;
using System.Threading.Tasks;
using System.Xml;
using System.Xml.Xsl;

namespace Maba.Connectors.EmailServices.MailTemplateTranformers
{
    public class XsltMailTemplateTranformer
    {
        #region private static memebrs

        private static MemoryCache CachedTransformers = null;

        #endregion

        #region static properties

        /// <summary>
        /// Seconds
        /// </summary>
        public static int MaxUnusedTransformers { get; set; }
        /// <summary>
        /// Seconds
        /// </summary>
        public static int MaxTTLTransformers { get; set; }

        #endregion

        #region ctor (static+instance)

        static XsltMailTemplateTranformer()
        {
            CachedTransformers = new MemoryCache(typeof(XsltMailTemplateTranformer).Name);
        }

        public XsltMailTemplateTranformer()
        {

        }

        #endregion

        #region public methods

        public async Task<string> Transform(string UsageKey, string TemplateURI, object DataSourceRecord, IEnumerable<ParameterValue> Parameters = null)
        {
            using (var ss = new MemoryStream())
            {
                await Transform(UsageKey, TemplateURI, DataSourceRecord, ss, Parameters);

                var bytes = new byte[ss.Length];
                ss.Position = 0;
                await ss.ReadAsync(bytes, 0, bytes.Length);
                return System.Text.ASCIIEncoding.UTF8.GetString(bytes);
            }
        }

        public async Task Transform(string UsageKey, string TemplateURI, object DataSourceRecord, Stream OutputStream, IEnumerable<ParameterValue> Parameters = null)
        {
            var cachedTransformer = CachedTransformers[UsageKey] as XslCompiledTransform;

            #region get transformer from cache (or create if none)

            if (cachedTransformer == null)
            {
                cachedTransformer = new XslCompiledTransform(true);
                cachedTransformer.Load(TemplateURI);

                CachedTransformers.Add(
                    new CacheItem(UsageKey, cachedTransformer, null),
                    new CacheItemPolicy()
                    {
                        AbsoluteExpiration = new DateTimeOffset(DateTime.UtcNow.AddSeconds(MaxTTLTransformers)),
                        SlidingExpiration = TimeSpan.FromSeconds(MaxUnusedTransformers)
                    });
            }

            #endregion

            XsltArgumentList list = null;
            if (Parameters != null)
            {
                list = new XsltArgumentList();
                foreach (var p in Parameters)
                {
                    if (String.IsNullOrEmpty(p.Name))
                    {
                        list.AddExtensionObject(p.NamespaceUri, p.Value);
                    }
                    else
                    {
                        list.AddParam(p.Name, p.NamespaceUri, p.Value);
                    }
                }
            }

            await Task.Run(() =>
                {
                    using (var s = new MemoryStream())
                    {
                        var xmlSer = new System.Xml.Serialization.XmlSerializer(DataSourceRecord.GetType());
                        xmlSer.Serialize(s, DataSourceRecord);

                        s.Position = 0;

                        using (var xmlReader = XmlReader.Create(s))
                        {
                            cachedTransformer.Transform(xmlReader, list, OutputStream);
                        }
                    }
                });
        }

        #endregion
    }
}
