using System;
using System.IO.Ports;
using Modbus.Device;

class Program
{
    static void Main()
    {
        string portName = "COM6";  // Change this to match your RS485 port
        int baudRate = 9600;
        int dataBits = 8;
        Parity parity = Parity.None;
        StopBits stopBits = StopBits.One;
        byte slaveId = 1;  // Adjust based on your Optidew configuration

        using (SerialPort serialPort = new SerialPort(portName, baudRate, parity, dataBits, stopBits))
        {
            try
            {
                serialPort.Open();




                // Create Modbus RTU master
                var modbusMaster = ModbusSerialMaster.CreateRtu(serialPort);


                // Adjust the register address based on the Optidew Modbus map
                ushort registerAddress = 0x0002;  // Example address, check Optidew documentation
                ushort[] response = modbusMaster.ReadHoldingRegisters(slaveId, registerAddress, 2);
                float dewPoint = ConvertRegistersToFloat(response[0], response[1]);
                //Console.WriteLine("Daw point: " + dewPoint);
                registerAddress = 0x0008;  // Example address, check Optidew documentation
                response = modbusMaster.ReadHoldingRegisters(slaveId, registerAddress, 2);
                float Temperature = ConvertRegistersToFloat(response[0], response[1]);
                //Console.WriteLine("Temperature: " + Temperature);
                Console.WriteLine($"Humidity: {dewPoint}% RH, Temperature {Temperature} Celsius");



                serialPort.Close();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }

    }
    static float ConvertRegistersToFloat(ushort msw, ushort lsw)
    {
        // Combine registers into a 32-bit integer
        uint combined = ((uint)msw << 16) | lsw;

        // Convert to bytes and then to a float
        byte[] bytes = BitConverter.GetBytes(combined);
        return BitConverter.ToSingle(bytes, 0);
    }
}
