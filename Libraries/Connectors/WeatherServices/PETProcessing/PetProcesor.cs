using Maba.Connectors.ElasticsearchLibrary;
using Maba.Connectors.WeatherServices.PETProcessing.AgricultureData;
using Maba.Connectors.WeatherServices.Providers;
using Maba.Connectors.WeatherServices.Settings;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static System.Net.Mime.MediaTypeNames;
using Maba.Connectors.WeatherServices.Providers.Models;
using System.IO;
//using Maba.Connectors.AWS.S3;
using Maba.Connectors.WeatherServices.Providers.Models.History;

namespace Maba.Connectors.WeatherServices.PETProcessing
{
    public class PetProcesor
    {
        //#region properties
        //public PET_Setting Setting { set; get; }
        //public IAgricultureData AgricultureData { set; get; }

        //#endregion

        //#region members

        //private Monthly_Values[] Monthly_List = null;
        //private Location Location = null;
        //private IWeatherProviderHistorical _WeatherProvider = null;
        //private BaseS3Connector S3 = null;
        //private MemoryStream _MemoryStream = null;

        //#endregion

        //#region public function
        //public PetProcesor(IAgricultureData AgricultureDataConnector,
        //                  PET_Setting setting)
        //{
        //    Setting = setting;
        //    _WeatherProvider = ForecastWeatherSettings.GetHistoricalProvider(setting.WeatherProviderSetting);
        //    AgricultureData = AgricultureDataConnector;
        //}


        //public AgricultureRecord GetCalculated(Location location)
        //{
        //    Location = location;
        //    //1.Get PET from Elastic in the MinDistance km radius
        //    AgricultureRecord pet = AgricultureData.GetPETRecord(location, Setting.MinDistance);

        //    if (pet != null)
        //    {
        //        return pet;
        //    }

        //    pet = new AgricultureRecord() { SID = string.Empty, location = Location, RecordDate = DateTime.UtcNow };

        //    //2.Get following Observation of weather for year
        //    GetWeatherHistory(pet);

        //    //3.calculation analysis algorithm max pet && daliy per month
        //    CalculationAlgorithm_PET(pet);

        //    //4.Save pet to ELK
        //    var list = AgricultureData.AddPETRecords(new List<AgricultureRecord>() { pet });

        //    return pet;

        //}
        //#endregion

        //#region private function
        //private void GetWeatherHistory(AgricultureRecord Record)
        //{
        //    #region Get Montly Values

        //    Task[] taskArray = new Task[12];
        //    Monthly_List = new Monthly_Values[12];
        //    for (int i = 0; i < taskArray.Length; i++)
        //    {
        //        int Month = i + 1;
        //        taskArray[i] = Task.Factory.StartNew(() => { GetMontlyData(Record, Month); });
        //    }
        //    Task.WaitAll(taskArray);

        //    #endregion

        //    #region Get Total Values

        //    double temp_min = -1;
        //    double temp_max = -1;

        //    double hr_min = -1;
        //    double hr_max = -1;

        //    var m_name = "";
        //    for (int i = 0; i < Monthly_List.Length; i++)
        //    {
        //        var m = Monthly_List[i];
        //        temp_min = temp_min == -1 ? m.Temp.MIN : Math.Min(temp_min, m.Temp.MIN);
        //        if (temp_max < m.Temp.MAX)
        //        {
        //            temp_max = Math.Max(temp_max, m.Temp.MAX);
        //            m_name = GETMontName(i + 1);
        //        }

        //        hr_min = hr_min == -1 ? m.Humidity.MIN : Math.Min(hr_min, m.Humidity.MIN);
        //        hr_max = Math.Max(hr_max, m.Humidity.MAX);
        //    }

        //    Record.HottestMonth = m_name;
        //    Record.Total_Summary_Humidity = new Summary_Values() { MAX = hr_max, MIN = hr_min };
        //    Record.Total_Summary_Temp = new Summary_Values() { MAX = temp_max, MIN = temp_min };

        //    #endregion
        //}

        //private string GETMontName(int i)
        //{
        //    switch (i)
        //    {
        //        case 1:
        //            return "JAN";
        //        case 2:
        //            return "FEB";
        //        case 3:
        //            return "MAR";
        //        case 4:
        //            return "APR";
        //        case 5:
        //            return "MAY";
        //        case 6:
        //            return "JUN";
        //        case 7:
        //            return "JUL";
        //        case 8:
        //            return "AUG";
        //        case 9:
        //            return "SEP";
        //        case 10:
        //            return "OCT";
        //        case 11:
        //            return "NOV";
        //        case 12:
        //            return "DEC";
        //        default:
        //            return "";
        //    }
        //}

        //private void GetMontlyData(AgricultureRecord Record, int Month_Num)
        //{
        //    Summary_Values Temp = null;
        //    Summary_Values Humidity = null;

        //    var lastYear = DateTime.Now.AddYears(-1).Year;
        //    DateTime d = new DateTime(lastYear, Month_Num, 1);

        //    var ObservationDay = 0;
        //    double total_temp = 0;
        //    double total_hr = 0;

        //    var MonthHistory = _WeatherProvider.GetHistorical(Location.lat, Location.lon, d, d.AddMonths(1).AddDays(-1), "e");

        //    if (Setting.IsSaveDataFile && !string.IsNullOrEmpty(Setting.DataFiles_URL) && MonthHistory.historyData.Length > 0)
        //    {
        //        SaveDataFile(MonthHistory, lastYear, Month_Num, Location);
        //    }

        //    if (string.IsNullOrEmpty(Record.SID))
        //    {
        //        var item = MonthHistory.historyData[0];
        //        Record.StationName = item.StationName;
        //        Record.SID = item.StationID;
        //    }

        //    Temp = new Summary_Values() { MIN = -1 };
        //    Humidity = new Summary_Values() { MIN = -1 };
        //    ObservationDay = 0;
        //    total_temp = 0;
        //    total_hr = 0;

        //    var lastDay = -1;
        //    foreach (var item in MonthHistory.historyData)
        //    {
        //        var dayItem = item.date.Day;

        //        if (lastDay != dayItem && item.date.Month == Month_Num)
        //        {
        //            lastDay = dayItem;
        //            ObservationDay++;
        //        }

        //        var Temp_Value = (double)item.Temp_Celsius.Avg.GetValueOrDefault(0);
        //        var Humidity_Value = (double)item.AvgHumidity.GetValueOrDefault(0);

        //        total_temp += Temp_Value;
        //        Temp.MIN = Temp.MIN == -1 ? Temp_Value : Math.Min(Temp.MIN, Temp_Value);
        //        Temp.MAX = Math.Max(Temp.MAX, Temp_Value);

        //        total_hr += Humidity_Value;
        //        Humidity.MIN = Humidity.MIN == -1 ? Humidity_Value : Math.Min(Humidity.MIN, Humidity_Value);
        //        Humidity.MAX = Math.Max(Humidity.MAX, Humidity_Value);
        //    }

        //    Temp.AVG = Math.Round((total_temp / MonthHistory.historyData.Length), 3);
        //    Humidity.AVG = Math.Round((total_hr / MonthHistory.historyData.Length), 3);

        //    Temp.MAX = Math.Round(Temp.MAX, 3);
        //    Temp.MIN = Math.Round(Temp.MIN, 3);

        //    Humidity.MAX = Math.Round(Humidity.MAX, 3);
        //    Humidity.MIN = Math.Round(Humidity.MIN, 3);

        //    var DaysNumber = DateTime.DaysInMonth(lastYear, Month_Num);

        //    var Month = new Monthly_Values()
        //    {
        //        Humidity = Humidity,
        //        Temp = Temp,
        //        ObservationDay = ObservationDay,
        //        DaysNumber = DaysNumber,
        //        MonthOrderNumber = Month_Num,
        //        PETUnitsType = "cm",
        //        TempUnitsType = "Celsius"
        //    };

        //    switch (Month_Num)
        //    {
        //        case 1:
        //            Record.JAN = Month;
        //            break;
        //        case 2:
        //            Record.FEB = Month;
        //            break;
        //        case 3:
        //            Record.MAR = Month;
        //            break;
        //        case 4:
        //            Record.APR = Month;
        //            break;
        //        case 5:
        //            Record.MAY = Month;
        //            break;
        //        case 6:
        //            Record.JUN = Month;
        //            break;
        //        case 7:
        //            Record.JUL = Month;
        //            break;
        //        case 8:
        //            Record.AUG = Month;
        //            break;
        //        case 9:
        //            Record.SEP = Month;
        //            break;
        //        case 10:
        //            Record.OCT = Month;
        //            break;
        //        case 11:
        //            Record.NOV = Month;
        //            break;
        //        case 12:
        //            Record.DEC = Month;
        //            break;
        //    }

        //    Monthly_List[Month_Num - 1] = Month;

        //}

        //private void SaveDataFile(ObservationsData monthHistory, int lastYear, int month_Num, Location Location)
        //{
        //    DateTime date = new DateTime(lastYear, month_Num, 1);
        //    var fileName = string.Format(Setting.DataFileName, date.ToString("yyyy"), date.ToString("MM"), (int)(Location.lat * 1000), (int)(Location.lon * 1000));

        //    #region Print heders

        //    fileName = string.Format("{0}\\{1}", Setting.DataFiles_URL, fileName);

        //    StringBuilder sb = new StringBuilder(120);
        //    using (System.IO.StreamWriter file = new System.IO.StreamWriter(fileName, true, Encoding.UTF8, 32768)) //32k
        //    {

        //        var lines = string.Format("{0},{1}", "Record:", DateTime.Now.ToString("yyyy-MM-dd")) + Environment.NewLine;
        //        file.WriteLine(lines);

        //        lines = string.Format("{0},{1},{2}", "Location:", "Lat:" + Location.lat, "Lon:" + Location.lon) + Environment.NewLine;
        //        file.WriteLine(lines);

        //        if (monthHistory.historyData.Length > 0)
        //        {
        //            var Item_0 = monthHistory.historyData[0];
        //            lines = string.Format("{0},{1}", "SID:", Item_0.StationID) + Environment.NewLine;
        //            file.WriteLine(lines);

        //            lines = string.Format("{0},{1}", "Station Name:", Item_0.StationName) + Environment.NewLine;
        //            file.WriteLine(lines);
        //        }

        //        sb.AppendLine("DateTime yyyy/MM/ HH:mm:ss," +
        //                 "Expire_time_gmt," +
        //                "DaytimeType," +
        //                "DescriptionWeather," +
        //                "icon," +
        //                "DewPoint," +
        //                "Description_Qualifier," +
        //                "Description_Rank," +
        //                "WindSpeed," +
        //                "WindDirection," +
        //                "CloudCover," +
        //                "Visibilities," +
        //                "Fahrenheit_Temp.Max," +
        //                "Fahrenheit_Temp.Min," +
        //                "Fahrenheit_Temp.Avg," +
        //                "Celsius_Temp.Max," +
        //                "Celsius_Temp.Min," +
        //                "Celsius_Temp.Avg," +
        //                "Prec_Total_Inch," +
        //                "Prec_hrly_Inch," +
        //                "Prec_Total_mm," +
        //                "Prec_hrly_mm," +
        //                "snow_hrly_Inch," +
        //                "snow_hrly_mm," +
        //                "AvgHumidity," +
        //                "Pressure," +
        //                "Description_Phrase," +
        //                "Description_Phrase2," +
        //                "Pressure_desc," +
        //                "Pressure_tend");
        //        file.WriteLine(sb);

        //        #endregion

        //        #region Data fileds

        //        foreach (var item in monthHistory.historyData)
        //        {
        //            lines = item.date.ToString("yyyy/MM/ HH:mm:ss") + ',' +
        //                  item.dt + ',' +
        //                 item.Daytime.ToString() + ',' +
        //                 item.DescriptionWeather + ',' +
        //                 item.icon.Code + ',' +
        //                 item.DewPoint + ',' +
        //                 item.Description_Qualifier + ',' +
        //                 item.Description_Rank + ',' +
        //                 item.WindSpeed + ',' +
        //                 item.WindDirection + ',' +
        //                 item.CloudCover + ',' +
        //                 item.Visibilities + ',' +
        //                 item.Temp_Fahrenheit.Max + ',' +
        //                 item.Temp_Fahrenheit.Min + ',' +
        //                 item.Temp_Fahrenheit.Avg + ',' +
        //                 item.Temp_Celsius.Max + ',' +
        //                 item.Temp_Celsius.Min + ',' +
        //                 item.Temp_Celsius.Avg + ',' +
        //                 item.Prec_Inch.Total + ',' +
        //                 item.Prec_Inch.Hourly + ',' +
        //                 item.Prec_mm.Total + ',' +
        //                 item.Prec_mm.Hourly + ',' +
        //                 item.Snow_Inch.Hourly + ',' +
        //                 item.Snow_mm.Hourly + ',' +
        //                 item.AvgHumidity + ',' +
        //                 item.Pressure + ',' +
        //                 item.Description_Phrase + ',' +
        //                 item.Description_Phrase2 + ',' +
        //                 item.Pressure_desc + ',' +
        //                 item.Pressure_tend;
        //            file.WriteLine(lines);
        //        }

        //        //  byte[] array = Encoding.ASCII.GetBytes(sb.ToString());
        //        #endregion
        //    }
        //}

        //private void CalculationAlgorithm_PET(AgricultureRecord Record)
        //{
        //    /**Ii = (Ti / 5)^1.514

        //    J = ∑ i = 1 ^12(Ii)

        //    c = 0.0000006758(J^3) - 0.0000771*(J^2) + 0.01792*J + 0.49239

        //    PETi(0) = 1.6 *((10*Ti / J)^c)

        //    PETi(L) = K PETi(0)**/

        //    Type t = typeof(AgricultureRecord);

        //    //1.Get J Value
        //    decimal J = 0;
        //    for (int y = 0; y < Monthly_List.Length; y++)
        //    {
        //        var m = Monthly_List[y];
        //        var temp = Math.Max(m.Temp.AVG, 0);
        //        var i = Math.Pow((temp / 5), 1.514);
        //        J += (decimal)i;
        //    }

        //    //2.C value 
        //    //   c = 0.000000675*(J^3) - 0.0000771*(J^2) + 0.01792^J + 0.49239
        //    //          a1              b1            x1
        //    var a1 = 0.000000675 * Math.Pow((double)J, 3);
        //    var b1 = 0.0000771 * Math.Pow((double)(J), 2);
        //    var x1 = (decimal)(0.01792m * J);
        //    var c = (decimal)a1 - (decimal)b1 + x1 + 0.49239m;



        //    //PETi(0) = 1.6(10*Ti / J) ^ c

        //    //PETi(L) = K PETi(0) * */


        //    for (int y = 0; y < Monthly_List.Length; y++)
        //    {
        //        var m = Monthly_List[y];
        //        var temp = Math.Max(m.Temp.AVG, 0);
        //        var PETi_0 = 1.6 * Math.Pow(((10 * temp) / (double)J), (double)c);
        //        var K = Get_KValue(Location.lat, m.MonthOrderNumber);
        //        var PETi_L = K * PETi_0;
        //        m.MAXPET = Math.Round(PETi_L, 3);
        //        m.DailyPET = Math.Round((m.MAXPET / m.DaysNumber), 3);
        //    }

        //}

        //private Double Get_KValue(decimal lat, int MonthNum)
        //{
        //    Double KValue = 1;
        //    foreach (var item in PET_Setting.ConstantsValues)
        //    {
        //        if (item.Latitude < lat)
        //        {
        //            return item.MonthSConstantsValues[MonthNum - 1];
        //        }
        //    }

        //    return KValue;
        //}

        //#endregion

    }

}





