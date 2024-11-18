using Microsoft.Owin.Security.DataProtection;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Security
{
    public class ChangePhoneFormater : IDataProtector<ChangePhoneData>
    {
        #region members

        private IDataProtector _DataProtector = null;

        #endregion

        #region ctor

        public ChangePhoneFormater(IDataProtector dataProtector)
        {
            _DataProtector = dataProtector;

        }

        #endregion

        #region IDataProtector members

        public byte[] Protect(ChangePhoneData obj, string purpose = null)
        {
            if (obj == null)
            {
                throw new ArgumentNullException("obj");
            }

            var ms = new MemoryStream();
            using (var writer = ms.CreateWriter())
            {
                writer.Write(obj.NewPhoneNumber);
                writer.Write(purpose ?? "");
            }

            var protectedBytes = _DataProtector.Protect(ms.ToArray());
            return protectedBytes;
        }

        public string Protect2String(ChangePhoneData obj, string purpose = null)
        {
            var protectedBytes = Protect(obj, purpose);
            return Convert.ToBase64String(protectedBytes);
        }

        public ChangePhoneData Unprotect(byte[] protectedData, string purpose = null)
        {
            var unprotectedBytes = _DataProtector.Unprotect(protectedData);

            var ms = new MemoryStream(unprotectedBytes);
            using (var reader = ms.CreateReader())
            {
                var obj = new ChangePhoneData()
                {
                    NewPhoneNumber = reader.ReadString()
                };

                var protectedPurpose = reader.ReadString();
                if (String.Compare(protectedPurpose ?? "", purpose ?? "") != 0)
                {
                    throw new InvalidDataException();
                }

                return obj;
            }
        }

        public ChangePhoneData Unprotect(string protectedData, string purpose = null)
        {
            var protectedBytes = Convert.FromBase64String(protectedData);
            return Unprotect(protectedBytes, purpose);
        }
        public bool ValidateChangeToken(string newPhoneNumber, string token)
        {
            var validToken = Protect2String(new ChangePhoneData() { NewPhoneNumber = newPhoneNumber });
            return token == validToken.Substring(0, 5);
        }

        public string Protect2ShortToken(ChangePhoneData obj, string purpose = null)
        {
            var validToken = Protect2String(obj, purpose);

            return validToken.Substring(0, 5);
        }
        #endregion
    }
}
