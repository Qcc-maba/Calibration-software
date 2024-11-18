using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.SMSServices.Tools
{
    class Program
    {
        static void Main(string[] args)
        {
            var smsSettings = new SMSServices.SMSServiceSettings()
            {
                DefaultSenderName = "MabaSmart",
                InEnabled = true
            };
            smsSettings.AddKey(Connectors.NexmoClientSettings.KEY__API_KEY, "2d593260");
            smsSettings.AddKey(Connectors.NexmoClientSettings.KEY__API_SECRET, "b19791b1");

            var smsConnector = new SMSServices.Connectors.NexmoClientConnector(smsSettings);

            //var _Body = "שנה טובה ומבורכת. שנת בריאות, הצלחה והגשמה. תודה על שנה נפלאה. שנזכה לשנה מתוקה ומוצלחת אפילו עוד יותר. איתן רווח.";

            // var _Body = "אהלן שמוליק, כדי להקל על איתן החלטתי לבקש ממך לעשות את השיחה עם רלי. תעדכן איך היה";
            var _Body = "hello!";
            //  var _Body = "שמוליק ?";
            var targets = new KeyValuePair<string, string>[] {
               new KeyValuePair<string, string>("eitan","972545607831"),
               // new KeyValuePair<string, string>("reli","972502661994"),
             //   new KeyValuePair<string, string>("shmuel", "972547406075"),
                // new KeyValuePair<string, string>("eliran","972545486607"),
                //// new KeyValuePair<string, string>("benny","972547948816"),
                // new KeyValuePair<string, string>("tom","972544313807"),
               //  new KeyValuePair<string, string>("shoval","972523530919"),
              //   new KeyValuePair<string, string>("nitsan","972528084889"),
               //  new KeyValuePair<string, string>("yair","972547948800"),
               //  new KeyValuePair<string, string>("amnon","972547948836"),
               //  new KeyValuePair<string, string>("tinsky","972547242959")
            };


            foreach (var t in targets)
            {
                Console.WriteLine("Sending to {0} [{1}]", t.Key, t.Value);

                var message = new SMSMessage()
                {
                    Body = _Body,
                    Destination = t.Value
                };

                var sendingResult = smsConnector.SendAsync(message);
                sendingResult.Wait();
                Console.WriteLine(" - Result {0}", sendingResult.Result);
            }

            Console.WriteLine("Completed.");
        }
    }
}
