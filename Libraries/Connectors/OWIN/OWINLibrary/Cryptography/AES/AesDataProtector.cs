using Microsoft.Owin.Security.DataProtection;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.OWINLibrary.Cryptography.AES
{
    public class AesDataProtector : IDataProtector
    {
        string defaultKey = "_AesDataProtector_";
        // Fields
        private byte[] binaryKey;

        public string Key { get; private set; }

        // Constructors
        public AesDataProtector(string key)
        {
            Key = String.IsNullOrEmpty(key) ? defaultKey : key;

            using (var sha1 = new SHA256Managed())
            {
                this.binaryKey = sha1.ComputeHash(Encoding.UTF8.GetBytes(Key));
            }
        }
        private byte[] GenerateIV()
        {
            var iv = new byte[16];
            var rand = new Random();
            rand.NextBytes(iv);

            return iv;
        }

        // IDataProtector Methods
        public byte[] Protect(byte[] data)
        {
            byte[] dataHash;
            using (var sha = new SHA256Managed())
            {
                dataHash = sha.ComputeHash(data);
            }

            using (AesManaged aesAlg = new AesManaged())
            {
                aesAlg.Key = this.binaryKey;
                aesAlg.IV = GenerateIV();

                using (var encryptor = aesAlg.CreateEncryptor(aesAlg.Key, aesAlg.IV))
                using (var msEncrypt = new MemoryStream())
                {
                    msEncrypt.Write(aesAlg.IV, 0, 16);

                    using (var csEncrypt = new CryptoStream(msEncrypt, encryptor, CryptoStreamMode.Write))
                    using (var bwEncrypt = new BinaryWriter(csEncrypt))
                    {
                        bwEncrypt.Write(dataHash);
                        bwEncrypt.Write(data.Length);
                        bwEncrypt.Write(data);
                    }
                    var protectedData = msEncrypt.ToArray();

                    return protectedData;
                }
            }
        }

        public byte[] Unprotect(byte[] protectedData)
        {
            try
            {
                using (AesManaged aesAlg = new AesManaged())
                {
                    aesAlg.Key = this.binaryKey;

                    using (var msDecrypt = new MemoryStream(protectedData))
                    {
                        byte[] _iv = new byte[16];
                        msDecrypt.Read(_iv, 0, 16);

                        aesAlg.IV = _iv;

                        using (var decryptor = aesAlg.CreateDecryptor(aesAlg.Key, aesAlg.IV))
                        using (var csDecrypt = new CryptoStream(msDecrypt, decryptor, CryptoStreamMode.Read))
                        using (var brDecrypt = new BinaryReader(csDecrypt))
                        {
                            var signature = brDecrypt.ReadBytes(32);
                            var len = brDecrypt.ReadInt32();
                            var data = brDecrypt.ReadBytes(len);

                            byte[] dataHash;
                            using (var sha = new SHA256Managed())
                            {
                                dataHash = sha.ComputeHash(data);
                            }

                            if (!dataHash.SequenceEqual(signature))
                                throw new SecurityException("Signature does not match the computed hash");

                            return data;
                        }
                    }
                }
            }
            catch
            {
                return new byte[0];
            }
        }
    }
}
