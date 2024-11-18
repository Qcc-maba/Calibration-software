using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.StorageLibrary
{
    public interface IStorageConnector : IDisposable
    {
        Task<UploadResponse> UploadFileAsync(string filename, UploadRequest request);
        Task<UploadResponse> UploadFileStreamAsync(Stream stream, UploadRequest request);
        Task<UploadResponse> UploadDirectoryAsync(string DirectoryPath, UploadRequest request);
        Task<bool> DeleteFileAsync(string filename);
    }
}
