using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.ElasticsearchLibrary.Models
{
    public interface ICommonRecord
    {
        string Identifier { get; }
        DateTime RecordDate { get; }
        long RecordDateT { get; set; }
    }
}
