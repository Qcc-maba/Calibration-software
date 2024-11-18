using Microsoft.Owin.Security.DataProtection;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Security
{
    public class ObjectDataFormat<T> : IDataProtector<T> where T : class
    {
        #region members

        private IDataProtector _DataProtector = null;

        #endregion

        #region properties

        public bool SupportZip { get; set; }

        #endregion

        #region ctor

        public ObjectDataFormat(IDataProtector dataProtector)
        {
            _DataProtector = dataProtector;
            SupportZip = false;
        }

        #endregion

        #region IDataProtector members

        public byte[] Protect(T obj, string purpose = null)
        {
            var json_str = JsonConvert.SerializeObject(obj);
            var bytes = StreamExtensions.DefaultEncoding.GetBytes(json_str);

            if (SupportZip)
            {
                using (var memory = new MemoryStream())
                {
                    using (var compression = new GZipStream(memory, CompressionLevel.Optimal))
                    {
                        using (var writer = new BinaryWriter(compression))
                        {
                            writer.Write(bytes);
                        }
                    }

                    var protectedBytes = _DataProtector.Protect(memory.ToArray());
                    return protectedBytes;
                }
            }
            else
            {
                var protectedBytes = _DataProtector.Protect(bytes);
                return protectedBytes;
            }
        }

        public string Protect2String(T obj, string purpose = null)
        {
            var protectedBytes = Protect(obj, purpose);

            return Convert.ToBase64String(protectedBytes);
        }

        public T Unprotect(string protectedBytes, string purpose = null)
        {
            var protectedData = Convert.FromBase64String(protectedBytes);

            return Unprotect(protectedData, purpose);
        }

        public T Unprotect(byte[] protectedData, string purpose = null)
        {
            var unprotectedBytes = _DataProtector.Unprotect(protectedData);

            if (SupportZip)
            {
                using (var memory = new MemoryStream(unprotectedBytes))
                {
                    var unZippedBytes = new byte[1024];
                    using (var compression = new GZipStream(memory, CompressionMode.Decompress))
                    {
                        using (var reader = new BinaryReader(compression))
                        {
                            var len = reader.Read(unZippedBytes, 0, unZippedBytes.Length);
                            unprotectedBytes = new byte[len];
                            for (int i = 0; i < len; i++)
                            {
                                unprotectedBytes[i] = unZippedBytes[i];
                            }
                        }
                    }
                }

                var json = StreamExtensions.DefaultEncoding.GetString(unprotectedBytes);

                var obj = JsonConvert.DeserializeObject<T>(json);

                return obj;
            }
            else
            {
                var json = StreamExtensions.DefaultEncoding.GetString(unprotectedBytes);

                var obj = JsonConvert.DeserializeObject<T>(json);

                return obj;
            }
        }

        #endregion
    }
}
