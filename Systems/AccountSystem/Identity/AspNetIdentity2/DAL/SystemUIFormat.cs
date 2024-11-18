using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.DAL
{
    public class SystemUIFormat
    {
        public int UIFormatID { get; set; }
        public string LongDatePattern { get; set; }
        public string ShortDatePattern { get; set; }
        public string ShortTimePattern { get; set; }
        public string LongTimePattern { get; set; }
        public string CultureCode { get; set; }
        public string YearMonthPattern { get; set; }
        public string DisplayName { get; set; }
        public bool IsRightToLeft { get; set; }
        public byte StartDayOfWeek { get; set; }
    }
}
