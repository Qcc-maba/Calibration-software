using System;
using System.Diagnostics;
using System.IO;
using System.Threading;

class Program
{
    private static readonly string fortiSSLVPNPath = @"C:\Program Files\Fortinet\FortiClient\FortiSSLVPNdaemon.exe";

    static void Main(string[] args)
    {
        string serverAddress = "31.154.20.226";
        string username = "eliran";
        string password = "Ne2312#";

        try
        {
            if (!File.Exists(fortiSSLVPNPath))
            {
                throw new FileNotFoundException("FortiSSLVPNdaemon.exe not found. Please ensure FortiClient is installed correctly.");
            }

            Console.WriteLine($"Found FortiSSL VPN at: {fortiSSLVPNPath}");

            while (true)
            {
                Console.WriteLine("\nFortiClient SSL VPN Connection Manager");
                Console.WriteLine("------------------------------------");
                Console.WriteLine("1. Connect to VPN");
                Console.WriteLine("2. Disconnect from VPN");
                Console.WriteLine("3. Exit");
                Console.Write("\nEnter your choice (1-3): ");

                string choice = Console.ReadLine();

                switch (choice)
                {
                    case "1":
                        ConnectToVPN(serverAddress, username, password);
                        break;
                    case "2":
                        DisconnectFromVPN();
                        break;
                    case "3":
                        return;
                    default:
                        Console.WriteLine("Invalid choice. Please try again.");
                        break;
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
            Console.WriteLine("Press any key to exit...");
            Console.ReadKey();
        }
    }

    static void ConnectToVPN(string serverAddress, string username, string password)
    {
        try
        {
            var processStartInfo = new ProcessStartInfo
            {
                FileName = fortiSSLVPNPath,
                // Using the correct command format from the documentation
                Arguments = $"--server {serverAddress}:443 --username {username} --password {password} --keep-running",
                UseShellExecute = true,
                CreateNoWindow = false,
                WindowStyle = ProcessWindowStyle.Normal
            };

            using (var process = Process.Start(processStartInfo))
            {
                if (process != null)
                {
                    Console.WriteLine("Connecting to SSL VPN...");
                    process.WaitForExit(30000); // Wait up to 30 seconds
                    Console.WriteLine("VPN connection attempt completed. Please check FortiClient UI for status.");
                }
                else
                {
                    Console.WriteLine("Failed to start VPN connection process.");
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error connecting to VPN: {ex.Message}");
        }
    }

    static void DisconnectFromVPN()
    {
        try
        {
            var processStartInfo = new ProcessStartInfo
            {
                FileName = fortiSSLVPNPath,
                Arguments = "--stop",  // Command to stop the VPN connection from documentation
                UseShellExecute = true,
                CreateNoWindow = false,
                WindowStyle = ProcessWindowStyle.Normal
            };

            using (var process = Process.Start(processStartInfo))
            {
                if (process != null)
                {
                    Console.WriteLine("Disconnecting from VPN...");
                    process.WaitForExit(10000); // Wait up to 10 seconds
                    Console.WriteLine("VPN disconnect attempt completed. Please check FortiClient UI for status.");
                }
                else
                {
                    Console.WriteLine("Failed to start VPN disconnect process.");
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error disconnecting from VPN: {ex.Message}");
        }
    }
}