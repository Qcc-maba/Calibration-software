using Microsoft.Owin.Security.DataProtection;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Security
{
    public class ConfirmEmailFormater : IDataProtector<ConfirmEmailData>
    {
        #region members

        private IDataProtector _DataProtector = null;

        #endregion

        #region ctor

        public ConfirmEmailFormater(IDataProtector dataProtector)
        {
            _DataProtector = dataProtector;

        }

        #endregion

        #region IDataProtector members

        public byte[] Protect(ConfirmEmailData obj, string purpose = null)
        {
            if (obj == null)
            {
                throw new ArgumentNullException("obj");
            }

            var ms = new MemoryStream();
            using (var writer = ms.CreateWriter())
            {
                writer.Write(obj.ExpireDate.Ticks);
                writer.Write(obj.IssueDate.Ticks);
                writer.Write(obj.Email);
                writer.Write(purpose ?? "");
            }

            var protectedBytes = _DataProtector.Protect(ms.ToArray());
            return protectedBytes;
        }

        public string Protect2String(ConfirmEmailData obj, string purpose = null)
        {
            var protectedBytes = Protect(obj, purpose);
            return Convert.ToBase64String(protectedBytes);
        }

        public ConfirmEmailData Unprotect(byte[] protectedData, string purpose = null)
        {
            var unprotectedBytes = _DataProtector.Unprotect(protectedData);

            var ms = new MemoryStream(unprotectedBytes);
            using (var reader = ms.CreateReader())
            {
                var obj = new ConfirmEmailData()
                {
                    ExpireDate = new DateTime(reader.ReadInt64()),
                    IssueDate = new DateTime(reader.ReadInt64()),
                    Email = reader.ReadString()
                };

                var protectedPurpose = reader.ReadString();
                if (String.Compare(protectedPurpose ?? "", purpose ?? "") != 0)
                {
                    throw new InvalidDataException();
                }

                return obj;
            }
        }

        public ConfirmEmailData Unprotect(string protectedData, string purpose = null)
        {
            var protectedBytes = Convert.FromBase64String(protectedData);
            return Unprotect(protectedBytes, purpose);
        }

        #endregion
    }
}
