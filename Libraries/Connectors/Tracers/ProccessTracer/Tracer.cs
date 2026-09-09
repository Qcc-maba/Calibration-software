using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Libs.Trace
{
    public class Tracer
    {
        #region static properties
        public static Tracer CurrentTracer { get; set; }

        #endregion

        #region static ctor

        static Tracer()
        {
            CurrentTracer = new Tracer()
            {
                OutputStream = Console.Out,
                SupportsColors = true
            };
        }

        #endregion

        #region properties

        public TextWriter OutputStream { get; set; }
        public bool SupportsColors { get; private set; } = false;

        #endregion

        #region static methods

        public static void Trace(string type, string format, params object[] args)
        {
#if TRACE
            CurrentTracer.OutputStream.WriteLine($"{type} :: {DateTime.Now.ToString("yyyyMMdd-HH:mm:ss.fff")} ::" + String.Format(format, args));
#endif
        }

        public static void Info()
        {
#if TRACE
            CurrentTracer.OutputStream.WriteLine();
#endif
        }
        public static void Info(string format, params object[] args)
        {
#if TRACE
            Info(false, format, args);
#endif
        }

        public static void Info(bool Colored, string format, params object[] args)
        {
#if TRACE
            if (Colored && CurrentTracer.SupportsColors)
            {
                Console.ForegroundColor = ConsoleColor.Green;
            }
            Trace("INFO", format, args);
            if (Colored && CurrentTracer.SupportsColors)
            {
                Console.ForegroundColor = ConsoleColor.Gray;
            }
#endif
        }

        public static void Error(string format, params object[] args)
        {
#if TRACE
            if (CurrentTracer.SupportsColors)
            {
                Console.ForegroundColor = ConsoleColor.Red;
            }
            Trace("ERROR", format, args);
            if (CurrentTracer.SupportsColors)
            {
                Console.ForegroundColor = ConsoleColor.Gray;
            }
#endif
        }

        public static void Debug(string format, params object[] args)
        {
#if TRACE
            Trace("DEBUG", format, args);
#endif
        }

        public static void Exception(string title, Exception e)
        {
#if TRACE
            if (CurrentTracer.SupportsColors)
            {
                Console.ForegroundColor = ConsoleColor.DarkRed;
            }
            Trace("EXCEPTION", $"{title} - [{e.GetType().Name}] {e.Message}");
            if (CurrentTracer.SupportsColors)
            {
                Console.ForegroundColor = ConsoleColor.Gray;
            }
#endif
        }

        #endregion
    }
}
