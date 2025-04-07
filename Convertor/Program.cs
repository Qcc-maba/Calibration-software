using System;
using System.IO;
using System.Windows.Forms;

class Program
{

    static void Main(string[] args)
    {
        Console.WriteLine("Map to PNG Converter");

        while (true)
        {
            Console.Write("Enter input .map file path: ");
            var dlg = new OpenFileDialog();
            if (dlg.ShowDialog() != DialogResult.OK)
                return;

            string inputFile = dlg.FileName;

            if (string.IsNullOrWhiteSpace(inputFile))
                break;

            Console.Write("Enter output .png file path: ");
            string outputFile = Console.ReadLine();

            try
            {
                ConvertMapToPng(inputFile, outputFile);
                Console.WriteLine($"Successfully converted {inputFile} to {outputFile}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }

            Console.WriteLine("\nPress Enter to convert another file, or leave input blank to exit.");
        }
    }

    static void ConvertMapToPng(string inputFile, string outputFile)
    {
        inputFile = inputFile.Remove('?');

        byte[] fileBytes = File.ReadAllBytes(inputFile);

        if (IsValidPngFile(fileBytes))
        {
            File.Copy(inputFile, outputFile, true);
            return;
        }

        int pngStartIndex = FindPngStartIndex(fileBytes);
        if (pngStartIndex != -1)
        {
            byte[] pngBytes = new byte[fileBytes.Length - pngStartIndex];
            Array.Copy(fileBytes, pngStartIndex, pngBytes, 0, pngBytes.Length);

            File.WriteAllBytes(outputFile, pngBytes);
        }
        else
        {
            throw new Exception("No PNG data found in the file");
        }
    }

    static bool IsValidPngFile(byte[] fileBytes)
    {
        byte[] pngSignature = new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };

        if (fileBytes.Length < pngSignature.Length)
            return false;

        for (int i = 0; i < pngSignature.Length; i++)
        {
            if (fileBytes[i] != pngSignature[i])
                return false;
        }
        return true;
    }

    static int FindPngStartIndex(byte[] fileBytes)
    {
        byte[] pngSignature = new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };

        for (int i = 0; i <= fileBytes.Length - pngSignature.Length; i++)
        {
            bool found = true;
            for (int j = 0; j < pngSignature.Length; j++)
            {
                if (fileBytes[i + j] != pngSignature[j])
                {
                    found = false;
                    break;
                }
            }
            if (found)
                return i;
        }
        return -1;
    }
}