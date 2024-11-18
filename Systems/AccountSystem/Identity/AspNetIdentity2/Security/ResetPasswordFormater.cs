using Microsoft.Owin.Security.DataProtection;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Security
{
    public class ResetPasswordFormater : IDataProtector<ResetPasswordData>
    {
        #region members

        private IDataProtector _DataProtector = null;

        #endregion

        #region ctor

        public ResetPasswordFormater(IDataProtector dataProtector)
        {
            _DataProtector = dataProtector;

        }

        #endregion

        #region IDataProtector members

        public byte[] Protect(ResetPasswordData obj, string purpose = null)
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
                writer.Write(obj.UserID);
                writer.Write(purpose ?? "");
            }

            var protectedBytes = _DataProtector.Protect(ms.ToArray());
            return protectedBytes;
        }

        public string Protect2String(ResetPasswordData obj, string purpose = null)
        {
            var protectedBytes = Protect(obj, purpose);
            return Convert.ToBase64String(protectedBytes);
        }

        public ResetPasswordData Unprotect(byte[] protectedData, string purpose = null)
        {
            var unprotectedBytes = _DataProtector.Unprotect(protectedData);

            var ms = new MemoryStream(unprotectedBytes);
            using (var reader = ms.CreateReader())
            {
                var obj = new ResetPasswordData()
                {
                    ExpireDate = new DateTime(reader.ReadInt64()),
                    IssueDate = new DateTime(reader.ReadInt64()),
                    Email = reader.ReadString(),
                    UserID = reader.ReadInt64()
                };

                var protectedPurpose = reader.ReadString();
                if (String.Compare(protectedPurpose ?? "", purpose ?? "") != 0)
                {
                    throw new InvalidDataException();
                }

                return obj;
            }
        }

        public ResetPasswordData Unprotect(string protectedData, string purpose = null)
        {
            var protectedBytes = Convert.FromBase64String(protectedData);
            return Unprotect(protectedBytes, purpose);
        }

        #endregion
    }
}
