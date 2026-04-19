using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Windows.Forms;

class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        Console.WriteLine("Map to JPEG Converter");
        Console.WriteLine("Select the root folder containing MAP files...");

        var dlg = new FolderBrowserDialog
        {
            Description = "Select folder containing MAP files",
            ShowNewFolderButton = false
        };

        if (dlg.ShowDialog() != DialogResult.OK)
            return;

        string rootFolder = dlg.SelectedPath;
        Console.WriteLine($"Processing folder: {rootFolder}\n");

        int converted = 0;
        int errors = 0;

        ProcessFolder(rootFolder, ref converted, ref errors);

        Console.WriteLine($"\nDone! Converted: {converted}, Errors: {errors}");
        Console.WriteLine("Press any key to exit.");
        Console.ReadKey();
    }

    static void ProcessFolder(string folderPath, ref int converted, ref int errors)
    {
        // Process MAP files in this folder
        foreach (string mapFile in Directory.GetFiles(folderPath, "*.map", SearchOption.TopDirectoryOnly))
        {
            string outputFile = Path.ChangeExtension(mapFile, ".jpg");
            try
            {
                ConvertMapToJpeg(mapFile, outputFile);
                Console.WriteLine($"[OK]  {mapFile}");
                converted++;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ERR] {mapFile}: {ex.Message}");
                errors++;
            }
        }

        // Recurse into subfolders
        foreach (string subFolder in Directory.GetDirectories(folderPath))
        {
            Console.WriteLine($"\n[DIR] {subFolder}");
            ProcessFolder(subFolder, ref converted, ref errors);
        }
    }

    static void ConvertMapToJpeg(string inputFile, string outputFile)
    {
        byte[] fileBytes = File.ReadAllBytes(inputFile);

        // Try JPEG first (0xFF 0xD8 0xFF)
        int jpegStart = FindSignature(fileBytes, new byte[] { 0xFF, 0xD8, 0xFF });
        if (jpegStart != -1)
        {
            byte[] imageBytes = new byte[fileBytes.Length - jpegStart];
            Array.Copy(fileBytes, jpegStart, imageBytes, 0, imageBytes.Length);
            using (var ms = new MemoryStream(imageBytes))
            using (var img = Image.FromStream(ms))
                img.Save(outputFile, ImageFormat.Jpeg);
            return;
        }

        // Try PNG (0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A)
        int pngStart = FindSignature(fileBytes, new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A });
        if (pngStart != -1)
        {
            byte[] imageBytes = new byte[fileBytes.Length - pngStart];
            Array.Copy(fileBytes, pngStart, imageBytes, 0, imageBytes.Length);
            using (var ms = new MemoryStream(imageBytes))
            using (var img = Image.FromStream(ms))
                img.Save(outputFile, ImageFormat.Jpeg);
            return;
        }

        throw new Exception("No image data (JPEG or PNG) found in file");
    }

    static int FindSignature(byte[] data, byte[] signature)
    {
        for (int i = 0; i <= data.Length - signature.Length; i++)
        {
            bool match = true;
            for (int j = 0; j < signature.Length; j++)
            {
                if (data[i + j] != signature[j]) { match = false; break; }
            }
            if (match) return i;
        }
        return -1;
    }
}
