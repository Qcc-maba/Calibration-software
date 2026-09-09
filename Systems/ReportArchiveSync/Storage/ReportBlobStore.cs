using System.Security.Cryptography;
using Amazon.S3;
using Amazon.S3.Model;
using Maba.VCT.ReportArchiveSync.Options;
using Microsoft.Extensions.Options;

namespace Maba.VCT.ReportArchiveSync.Storage;

/// <summary>Outcome of mirroring one archive file into S3.</summary>
/// <param name="Skipped">
/// True when an object written by something else already holds the key and was left untouched.
/// </param>
public sealed record UploadResult(
    string StorageKey, byte[] Sha256, long Length, bool Uploaded, bool Skipped = false);

/// <summary>
/// Copies report PDFs from the Tomax archive into the bucket the web app reads.
/// </summary>
/// <remarks>
/// <para>
/// The SHA-256 of the source file is stored as object metadata, so a later cycle can tell an
/// unchanged file from a re-issued one without downloading the object back. That matters: the
/// service re-reads the whole archive every cycle, and re-uploading ~7,400 PDFs an hour would be
/// pure waste.
/// </para>
/// <para>
/// The S3 client is taken lazily. A dry run has to be startable on a machine with no AWS
/// credentials or region configured at all — that is the entire point of dry run — and an eagerly
/// constructed client throws "No RegionEndpoint or ServiceURL configured" during host startup.
/// </para>
/// </remarks>
public sealed class ReportBlobStore(Lazy<IAmazonS3> s3, IOptions<ReportArchiveSyncOptions> options)
{
    private const string HashMetadataKey = "sha256";

    private readonly ReportArchiveSyncOptions _options = options.Value;

    private IAmazonS3 S3 => s3.Value;

    public static byte[] ComputeSha256(string path)
    {
        using var stream = File.OpenRead(path);
        return SHA256.HashData(stream);
    }

    /// <summary>
    /// Uploads <paramref name="sourcePath"/> to <paramref name="storageKey"/> unless an object
    /// with the same content is already there.
    /// </summary>
    /// <param name="protectForeignObject">
    /// Refuse to overwrite an object that this service did not write. Set for the canonical
    /// <c>report.pdf</c> key, which is also where the calibration wizard saves a report the
    /// calibrator produced and signed in the app — that file is the authority for its device and
    /// must never be replaced by an archived one.
    /// </param>
    public async Task<UploadResult> MirrorAsync(
        string sourcePath,
        string storageKey,
        CancellationToken cancellationToken,
        bool protectForeignObject = false)
    {
        var hash = ComputeSha256(sourcePath);
        var hex = Convert.ToHexStringLower(hash);
        var length = new FileInfo(sourcePath).Length;

        var existing = await DescribeAsync(storageKey, cancellationToken);

        if (existing is not null)
        {
            var storedHash = existing.Metadata[HashMetadataKey];

            if (string.Equals(storedHash, hex, StringComparison.OrdinalIgnoreCase))
            {
                // Same bytes already in place — nothing to do.
                return new UploadResult(storageKey, hash, length, Uploaded: false);
            }

            if (protectForeignObject && string.IsNullOrEmpty(storedHash))
            {
                // No hash metadata means it was not written by this service: an app-generated
                // report. Leave it alone and say so, rather than silently replacing a signed
                // report with an archived one.
                return new UploadResult(storageKey, hash, length, Uploaded: false, Skipped: true);
            }
        }

        await using var stream = File.OpenRead(sourcePath);

        var request = new PutObjectRequest
        {
            BucketName = _options.BucketName,
            Key = storageKey,
            InputStream = stream,
            ContentType = "application/pdf",
            AutoCloseStream = false,
        };

        request.Metadata.Add(HashMetadataKey, hex);

        await S3.PutObjectAsync(request, cancellationToken);

        return new UploadResult(storageKey, hash, length, Uploaded: true);
    }

    /// <summary>Object metadata, or null when nothing is stored under that key.</summary>
    private async Task<GetObjectMetadataResponse?> DescribeAsync(
        string storageKey, CancellationToken cancellationToken)
    {
        try
        {
            return await S3.GetObjectMetadataAsync(_options.BucketName, storageKey, cancellationToken);
        }
        catch (AmazonS3Exception ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }
}
