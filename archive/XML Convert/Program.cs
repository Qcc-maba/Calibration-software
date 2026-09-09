using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows.Forms;
using System.Xml;
using System.Xml.Linq;

class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        string xmlFilePath = "";
        using (OpenFileDialog openFileDialog = new OpenFileDialog())
        {
            openFileDialog.Filter = "Map Files (*.map)|*.map|All Files (*.*)|*.*";

            if (openFileDialog.ShowDialog() == DialogResult.OK)
            {
                xmlFilePath = openFileDialog.FileName;
            }
        }




        // Load the XML file
        XDocument xmlDoc = XDocument.Load(xmlFilePath);

        // Parse Report Information
        XElement information = xmlDoc.Root.Element("Information");
        Console.WriteLine("Report Information:");
        Console.WriteLine($"Name: {information.Element("Name").Value}");
        Console.WriteLine($"Date: {information.Element("Date").Value}");
        Console.WriteLine($"Department: {information.Element("Department").Value}");
        Console.WriteLine($"Author: {information.Element("Author").Value}");
        Console.WriteLine($"Instrument: {information.Element("Instrument").Value}");
        Console.WriteLine();

        // Parse Parameters
        Console.WriteLine("Parameters:");
        foreach (XElement parameter in xmlDoc.Root.Element("Parameters").Elements())
        {
            string bookmark = parameter.Element("Bookmark")?.Value ?? "N/A";
            string value = parameter.Element("Value")?.Value ?? "N/A";
            Console.WriteLine($"Bookmark: {bookmark}, Value: {value}");
        }
        Console.WriteLine();

        // Parse Tables
        Console.WriteLine("Tables:");
        foreach (XElement table in xmlDoc.Root.Element("Tables").Elements())
        {
            string tableName = table.Name.LocalName;
            string tableSize = table.Attribute("Size")?.Value ?? "Unknown";
            Console.WriteLine($"Table: {tableName}, Size: {tableSize}");

            // Extract rows and cells
            foreach (XElement row in table.Elements("Row"))
            {
                Console.WriteLine($" Row Index: {row.Attribute("Index")?.Value}");
                foreach (XElement cell in row.Elements("Cell"))
                {
                    string cellValue = cell.Element("Value")?.Value ?? "N/A";
                    Console.WriteLine($"  Cell Column: {cell.Attribute("Column")?.Value}, Value: {cellValue}");
                }
            }
        }
        Console.ReadLine();
    }
}
