using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using Maba.VCT.Core.Device.OTA;

namespace Hydra2.VCT.Core.Device.OTA
{
    public class OTAService
    {
        #region static properties

        //internal static Settings.VCTSettings CurrentServerSettings { get; set; }

        #endregion

        #region private methods

        private static string OTA_Metadata_Filename(string Code)
        {
            return String.Format("OTA_{0}.xml", Code);
        }

        //private static string OTA_Metadata_Path(string Code)
        //{
        //    return Path.Combine(CurrentServerSettings.Get_OTA_LocalStorageFolder(),
        //                        Code,
        //                        OTA_Metadata_Filename(Code));

        //}

        private static string OTA_Data_Filename(string Code)
        {
            return String.Format("OTA_{0}.DAT", Code);
        }

        //private static string OTA_Data_Path(string Code)
        //{
        //    var filename = Path.Combine(CurrentServerSettings.OTA_LocalStorageFolder,
        //                       Code,
        //                       OTA_Data_Filename(Code));

        //    return filename;
        //}

        //private static void Write_OTA_DataFile(string FileCode, byte[] Data)
        //{
        //    if (File.Exists(FileCode))
        //    {
        //        File.WriteAllBytes(OTA_Data_Path(FileCode), Data);
        //    }
        //}

        //private static OTAItem GetOTA_ReadLocal(string code, bool loadFile = false)
        //{
        //    var metadata = OTA_Metadata.Read(OTA_Metadata_Path(code));
        //    if (metadata != null)
        //    {
        //        var dataFilename = OTA_Data_Path(code);
        //        var otaItem = new OTAItem()
        //        {
        //            Metadata = metadata,
        //            LocalOTAData_FileName = dataFilename
        //        };

        //        if (loadFile)
        //        {
        //            otaItem.Data = File.ReadAllBytes(dataFilename);
        //        }

        //        return otaItem;
        //    }

        //    return null;
        //}

        #endregion

        #region public methods

        //public static UploadFileResponse UploadOTAFile(OTA_Metadata metadata, byte[] Data, bool OverrideExists)
        //{
        //    //validation
        //    if (metadata == null || metadata.FileCode == null)
        //    {
        //        return new UploadFileResponse(metadata, false, UploadFileResponse.Errors.Bad_Request);
        //    }

        //    #region check exists (local storage)

        //    var existsOTAItem = GetOTA(metadata.FileCode);
        //    if (existsOTAItem != null && !OverrideExists)
        //    {
        //        return new UploadFileResponse(metadata, false, UploadFileResponse.Errors.Already_Exists_Locally);
        //    }

        //    #endregion

        //    var response = new UploadFileResponse(metadata, false);

        //    #region Save local

        //    //metadata.CRC16 = Common.Hydra2ProtocolHelper.CalcCRC16(Data, 0, Data.Length);
        //    metadata.FileSize = Data.Length;

        //    //Write_OTA_DataFile(metadata.FileCode, Data);
        //    //metadata.Save(OTA_Metadata_Path(metadata.FileCode));

        //    #endregion

        //    #region Remote

        //    ////S3
        //    //Connectors.AWS.S3.BaseS3Connector S3 = new Connectors.AWS.S3.BaseS3Connector(new Connectors.AWS.S3.S3Settings());

        //    //FileStream fileStream = new FileStream(metadata.FileCode, FileMode.Open);

        //    //Connectors.AWS.S3.MessageRequest messageRequest = S3.Upload(fileStream, metadata.FileCode);


        //    #endregion

        //    return response;
        //}

        //public static async Task<OTAItem> GetOTA(string code)
        //{
        //    #region look for local copy

        //    var localOtaItem = GetOTA_ReadLocal(code);
        //    if (localOtaItem != null)
        //    {
        //        return localOtaItem;
        //    }

        //    #endregion

        //    #region look for remote storage

        //    var remoteURLStorage = CurrentServerSettings.OTA_RemoteStorageURL;

        //    if (String.IsNullOrEmpty(remoteURLStorage))
        //    {
        //        return null;
        //    }
        //    try
        //    {
        //        using (var client = new WebClient())
        //        {
        //            var metadataPath = OTA_Metadata_Path(code);

        //            var folderURL = new Uri(new Uri(remoteURLStorage), code);
        //            var metadataFolderURL = new Uri(folderURL, OTA_Metadata_Filename(code));
        //            var OTADataFolderURL = new Uri(folderURL, OTA_Data_Filename(code));

        //            await client.DownloadFileTaskAsync(OTADataFolderURL, metadataPath);

        //            if (File.Exists(metadataPath))
        //            {
        //                //metadata found in remote location. read the data file
        //                await client.DownloadFileTaskAsync(OTADataFolderURL, OTA_Data_Path(code));
        //            }
        //        }
        //    }
        //    catch
        //    {

        //    }

        //    var otaItem = GetOTA_ReadLocal(code);
        //    if (otaItem != null)
        //    {
        //        return otaItem;
        //    }

        //    #endregion

        //    return null;
        //}

        #endregion
    }
}
