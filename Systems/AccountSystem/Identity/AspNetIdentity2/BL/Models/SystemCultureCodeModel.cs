using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using Maba.AccountSystem.AspNetIdentity.Identity2.DAL;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.BL.Models
{
    public class SystemUIFormatModel
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

        //
        public SystemUIFormatModel()
        {

        }

        public SystemUIFormatModel(SystemUIFormat Culture)
        {
            UIFormatID = Culture.UIFormatID;
            LongDatePattern = Culture.LongDatePattern;
            ShortDatePattern = Culture.ShortDatePattern;
            ShortTimePattern = Culture.ShortTimePattern;
            LongTimePattern = Culture.LongTimePattern;
            CultureCode = Culture.CultureCode;
            YearMonthPattern = Culture.YearMonthPattern;
            DisplayName = Culture.DisplayName;
            IsRightToLeft = Culture.IsRightToLeft;
            StartDayOfWeek = Culture.StartDayOfWeek;
        }
    }
}