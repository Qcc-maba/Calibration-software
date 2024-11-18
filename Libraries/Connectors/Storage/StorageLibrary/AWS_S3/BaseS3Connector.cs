using Amazon;
using Amazon.S3;
using Amazon.S3.Model;
using Amazon.S3.Transfer;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.StorageLibrary.AWS_S3
{
    public class BaseS3Connector : IDisposable, IStorageConnector
    {
        private IAmazonS3 Connector;
        private S3Settings _setting = null;

        public string ObjectUrl { get; private set; }

        public BaseS3Connector(S3Settings setting)
        {
            _setting = setting;

            Connector = new AmazonS3Client(_setting.AwsAccessKeyId, _setting.AwsSecretAccessKey, GetRegionEndpoint(_setting.Region));
        }

        #region private methods
        private RegionEndpoint GetRegionEndpoint(string regionName)
        {
            foreach (var item in RegionEndpoint.EnumerableAllRegions)
            {
                if (item.SystemName == regionName)
                    return item;
            }

            return RegionEndpoint.APNortheast1;
        }
        private string _BuildTargetFolder(string key)
        {
            if (String.IsNullOrEmpty(_setting.DefaultFolder))
            {
                return key;
            }
            else
            {
                return _setting.DefaultFolder + "/" + key;
            }
        }
        private S3CannedACL Convert(ACLControl acl)
        {
            switch (acl)
            {
                case ACLControl.PublicRead:
                    return S3CannedACL.PublicRead;
                case ACLControl.PublicReadWrite:
                    return S3CannedACL.PublicReadWrite;
                case ACLControl.Private:
                    return S3CannedACL.Private;
                default:
                    return S3CannedACL.NoACL;
            }
        }

        private string ParseObjectURL(string bucketName, string TargetPath = null)
        {
            GetPreSignedUrlRequest signedRequest = new GetPreSignedUrlRequest
            {
                BucketName = bucketName,
                Key = TargetPath,
                Verb = HttpVerb.GET,
                Protocol = Protocol.HTTPS,
                Expires = DateTime.MaxValue
            };

            var fullUrl = Connector.GetPreSignedURL(signedRequest);
            int index = fullUrl.IndexOf("?");
            if (index > 0)
            {
                return fullUrl.Substring(0, index);
            }
            else
            {
                return fullUrl;
            }
        }

        #endregion

        public string[] ListAllBuckets()
        {
            var buckets = Connector.ListBuckets();

            return buckets.Buckets
                .Select(b => b.BucketName)
                .ToArray();
        }

        public bool CreateBucket(string BucketName)
        {
            PutBucketRequest request = new PutBucketRequest();
            request.BucketName = BucketName;
            var r = Connector.PutBucket(request);

            return r.HttpStatusCode == System.Net.HttpStatusCode.OK;
        }

        #region IStorageConnector members

        public async Task<UploadResponse> UploadFileAsync(string filePath, UploadRequest request)
        {
            var fileTransferUtility = new TransferUtility(Connector);
            var uploadRequest = new TransferUtilityUploadRequest
            {
                ContentType = request.ContentType,
                FilePath = filePath,
                Key = _BuildTargetFolder(request.TargetPath),
                BucketName = _setting.DefaultBucketName,
                CannedACL = Convert(request.ACL)
            };

            await fileTransferUtility.UploadAsync(uploadRequest);

            return new UploadResponse()
            {
                Result = true,
                ObjectFullUrl = ParseObjectURL(uploadRequest.BucketName, uploadRequest.Key),
            };
        }

        public async Task<UploadResponse> UploadFileStreamAsync(Stream _Stream, UploadRequest request)
        {
            var fileTransferUtility = new TransferUtility(Connector);
            var uploadRequest = new TransferUtilityUploadRequest
            {
                InputStream = _Stream,
                Key = _BuildTargetFolder(request.TargetPath),
                BucketName = _setting.DefaultBucketName,
                CannedACL = Convert(request.ACL)
            };

            await fileTransferUtility.UploadAsync(uploadRequest);

            return new UploadResponse()
            {
                Result = true,
                ObjectFullUrl = ParseObjectURL(uploadRequest.BucketName, uploadRequest.Key),
            };
        }

        public async Task<UploadResponse> UploadDirectoryAsync(string Directorypath, UploadRequest request)
        {
            var fileTransferUtility = new TransferUtility(Connector);
            var uploadRequest = new TransferUtilityUploadDirectoryRequest
            {
                Directory = Directorypath,
                BucketName = _setting.DefaultBucketName,
                KeyPrefix = _BuildTargetFolder(request.TargetPath),
                SearchOption = SearchOption.AllDirectories,
                CannedACL = Convert(request.ACL)
            };

            await fileTransferUtility.UploadDirectoryAsync(uploadRequest);

            return new UploadResponse()
            {
                Result = true,
                ObjectFullUrl = ParseObjectURL(uploadRequest.BucketName, uploadRequest.KeyPrefix),
            };
        }

        public async Task<bool> DeleteFileAsync(string filename)
        {
            var deleteRequest = new DeleteObjectRequest()
            {
                BucketName = _setting.DefaultBucketName,
                Key = _BuildTargetFolder(filename)
            };

            var response = await Connector.DeleteObjectAsync(deleteRequest);

            return (response.HttpStatusCode == System.Net.HttpStatusCode.OK) || (response.HttpStatusCode == System.Net.HttpStatusCode.NoContent);
        }

        #endregion

        #region IDisposable members

        public void Dispose()
        {
            Connector.Dispose();
            Connector = null;
        }

        #endregion
    }
}
