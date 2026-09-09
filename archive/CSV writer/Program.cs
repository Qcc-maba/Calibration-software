using OfficeOpenXml;
using System;
using System.Collections.Generic;
using System.IO;

namespace CSV_writer
{
    internal class Program
    {
        static void Main()
        {
            // Set EPPlus license context
            ExcelPackage.LicenseContext = LicenseContext.NonCommercial;

            // Define the output file path
            string filePath = "sensor_data.xlsx";

            using (var package = new ExcelPackage())
            {
                // First Tab (Data)
                var dataSheet = package.Workbook.Worksheets.Add("Data");

                // Headers for first tab
                string[] dataHeaders = new string[]
                {
                "Time elapsed [sec]",
                "21-473 - Ch_0",
                "21-473 - Ch_1",
                "21-473 - Ch_2",
                "21-473 - Ch_3",
                "21-473 - Ch_4",
                "21-473 - Ch_5",
                "21-473 - Ch_6",
                "21-473 - Ch_7",
                "21-473 - Ch_8",
                "21-473 - Ch_9",
                "21-473 - Ch_10"
                };

                // Add headers to first row and format
                for (int i = 0; i < dataHeaders.Length; i++)
                {
                    var cell = dataSheet.Cells[1, i + 1];
                    cell.Value = dataHeaders[i];
                    // Apply bold and underline
                    cell.Style.Font.Bold = true;
                    cell.Style.Font.UnderLine = true;
                }

                // Sample data (replace with your full dataset)
                List<double[]> dataRows = new List<double[]>
            {
                new double[] { 0, 100.621, 23.4, 23.5, 23.5, 23.6, 23.7, 23.1, 23.2, 23.3, 23.2, 23.5 },
                new double[] { 10, 100.536, 23.2, 23.5, 23.5, 23.7, 23.7, 23.0, 23.2, 23.3, 23.3, 23.5 },
                new double[] { 20, 100.622, 23.2, 23.5, 23.5, 23.7, 23.6, 22.9, 23.3, 23.3, 23.2, 23.3 }
            };

                // Add data rows
                for (int row = 0; row < dataRows.Count; row++)
                {
                    for (int col = 0; col < dataRows[row].Length; col++)
                    {
                        dataSheet.Cells[row + 2, col + 1].Value = dataRows[row][col];
                    }
                }

                // Second Tab (Metadata)
                var metadataSheet = package.Workbook.Worksheets.Add("Metadata");

                // Headers for second tab
                string[] metadataHeaders = new string[]
                {
                "Report ID", "Logger", "Channel", "Sensor", "Measurement", "Unit",
                "Starting time", "Note", "MinWorkRange", "MaxWorkRange", "Resolution"
                };

                // Add headers to first row of second tab and format
                for (int i = 0; i < metadataHeaders.Length; i++)
                {
                    var cell = metadataSheet.Cells[1, i + 1];
                    cell.Value = metadataHeaders[i];
                    // Apply bold and underline
                    cell.Style.Font.Bold = true;
                    cell.Style.Font.UnderLine = true;
                }

                // Metadata sample data
                object[,] metadata = new object[,]
                {
                {"2408446-011", "21-473", 0, "21-489", "Pressure absolute", "kPa a", "2024-08-20 11:35:11", "P1", 0.13632156, 999.9047599, 3},
                {"2408446-011", "21-473", 1, "21-691", "Temperature", "°C", "2024-08-20 11:35:11", "Ch_1", 0.0, 150.0, 1},
                {"2408446-011", "21-473", 2, "21-691", "Temperature", "°C", "2024-08-20 11:35:11", "Ch_2", 0.0, 150.0, 1}
                    // Add more rows for channels 3-10 as needed
                };

                // Add metadata rows
                for (int row = 0; row < metadata.GetLength(0); row++)
                {
                    for (int col = 0; col < metadata.GetLength(1); col++)
                    {
                        metadataSheet.Cells[row + 2, col + 1].Value = metadata[row, col];
                    }
                }

                // Auto-fit columns for better readability
                dataSheet.Cells.AutoFitColumns();
                metadataSheet.Cells.AutoFitColumns();

                // Save the Excel file
                try
                {
                    File.WriteAllBytes(filePath, package.GetAsByteArray());
                    Console.WriteLine($"Excel file with formatted headers has been created at: {Path.GetFullPath(filePath)}");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error writing Excel file: {ex.Message}");
                }
            }
        }
    }
}
