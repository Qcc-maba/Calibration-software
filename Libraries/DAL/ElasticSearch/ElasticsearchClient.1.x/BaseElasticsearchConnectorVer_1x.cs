
using Elasticsearch.Net;
using Nest;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.Elasticsearch
{
    public class BaseElasticsearchConnectorVer_1x : IDisposable
    {
        #region CONSTANTS

        public const long DATETIME_UNIX_1970_1JAN = 621355968000000000;
        public const string ELASTIC_HIT__FIELD_NAME_TIMESTAMP = "_timestamp";
        public const string ELASTIC_HIT__FIELD_NAME_SOURCE = "_source";

        public const string ELASTIC_TIMESTAMP_RECORD_PROPERTY = "Elastic_timeStamp";


        #endregion

        #region members

        private ElasticClient _Client = null;

        #endregion

        #region properties

        public ElasticSettings CurrentSettings { get; private set; }

        #endregion

        #region ctor

        public BaseElasticsearchConnectorVer_1x(ElasticSettings settings)
        {
            CurrentSettings = settings;

            var f = new ConnectionSettings(new Uri(CurrentSettings.Server_URL));
            _Client = new ElasticClient(f);
        }

        #endregion

        #region protected accessories methods
        protected Models.HitRecord[] Convert(IBulkResponse bulkRespose)
        {
            if (bulkRespose.Items != null)
            {
                return bulkRespose
                    .Items
                    .Select(s => new Models.HitRecord()
                    {
                        IsValid = s.IsValid,
                        Id = s.Id,
                        Index = s.Index,
                        Operation = s.Operation,
                        Status = s.Status,
                        Type = s.Type,
                        Version = string.IsNullOrEmpty(s.Version) ? -1 : int.Parse(s.Version)
                    })
                    .ToArray();
            }
            else
            {
                return new Models.HitRecord[0];
            }
        }
        protected string BuildIndexName(string baseIndexName, DateTime? fromDate, DateTime? toDate = null)
        {

            if (!fromDate.HasValue && !toDate.HasValue)
            {
                return "";
            }
            else if (fromDate.HasValue && !toDate.HasValue)
            {
                return String.Format("{0}_{1}", baseIndexName, fromDate.Value.ToString(this.CurrentSettings.Elastic_RollingIndex_DateFormat));
            }
            else if (!fromDate.HasValue && toDate.HasValue)
            {

                return String.Format("{0}_{1}", baseIndexName, toDate.Value.ToString(this.CurrentSettings.Elastic_RollingIndex_DateFormat));
            }
            else
            {
                string Indices = "";

                Indices = String.Format("{0}_{1}", baseIndexName, fromDate.Value.ToString(this.CurrentSettings.Elastic_RollingIndex_DateFormat));

                int index = 0;
                while (toDate.Value.Year > fromDate.Value.Year ||
                        (toDate.Value.Year == fromDate.Value.Year
                            && toDate.Value.Month > fromDate.Value.Month))
                {
                    Indices += String.Format("{0}{1}_{2}",
                                                (index > 0 ? "," : ""),
                                                baseIndexName, fromDate.Value.ToString(this.CurrentSettings.Elastic_RollingIndex_DateFormat));

                    index++;
                    fromDate = fromDate.Value.AddMonths(1);

                    if (index > this.CurrentSettings.MaxIndexsMultiSearch)
                    {
                        return "*";
                    }
                }


                return Indices;
            }
        }

        protected string BuildIndexName(string baseIndexName, long? fromTicks, long? toTicks = null)
        {
            DateTime fromDate;
            DateTime toDate;
            if (!fromTicks.HasValue && !toTicks.HasValue)
            {
                return "*";
            }
            else if (fromTicks.HasValue && !toTicks.HasValue)
            {
                fromDate = new DateTime(fromTicks.Value);
                return String.Format("{0}_{1}", baseIndexName, fromDate.ToString(this.CurrentSettings.Elastic_RollingIndex_DateFormat));
            }
            else if (!fromTicks.HasValue && toTicks.HasValue)
            {
                toDate = new DateTime(toTicks.Value);
                return String.Format("{0}_{1}", baseIndexName, toDate.ToString(this.CurrentSettings.Elastic_RollingIndex_DateFormat));
            }
            else
            {
                fromDate = new DateTime(fromTicks.Value);
                toDate = new DateTime(toTicks.Value);
                string Indices = String.Format("{0}_{1}", baseIndexName, fromDate.ToString(this.CurrentSettings.Elastic_RollingIndex_DateFormat));

                int index = 0;
                while (toDate.Year > fromDate.Year ||
                        (toDate.Year == fromDate.Year
                            && toDate.Month > fromDate.Month))
                {
                    Indices += String.Format("{0}{1}_{2}",
                                                (index > 0 ? "," : ""),
                                                baseIndexName, fromDate.ToString(this.CurrentSettings.Elastic_RollingIndex_DateFormat));

                    index++;
                    fromDate = fromDate.AddMonths(1);

                    if (index > this.CurrentSettings.MaxIndexsMultiSearch)
                    {
                        return "*";
                    }
                }

                return Indices;
            }
        }

        #endregion

        #region protected methods

        protected IIndexResponse InsertRecord<T>(string indexName, string type, T jobect, string Id = null) where T : class
        {
            if (String.IsNullOrEmpty(Id))
            {
                return _Client.Index(jobect, i => i
                   .Index(indexName)
                   .Type(type)
                 );
            }
            else
            {
                return _Client.Index(jobect, i => i
                   .Index(indexName)
                   .Type(type)
                   .Id(Id)
                 );
            }
        }

        protected IDeleteResponse DeleteRecord(string indexName, string type, string Id = null, string RoutingValue = null)
        {
            return _Client.Delete(new DeleteRequest(indexName, type, Id)
            {
                Routing = RoutingValue
            });
        }

        protected IBulkResponse BullkIndex<T>(string type,
            Func<T, string> IndexNameGenerator, IEnumerable<T> jobectS,
            Func<T, string> IdGenerator = null,
             string RoutingValue = null) where T : class
        {
            var descriptor = new BulkDescriptor();

            if (IdGenerator != null)
            {
                foreach (var j in jobectS)
                {
                    descriptor.Index<T>(i =>
                    {
                        i = i
                            .Index(IndexNameGenerator(j))
                            .Type(type)
                            .Id(IdGenerator(j))
                            .Document(j);

                        if (RoutingValue != null)
                        {
                            i = i.Routing(RoutingValue);
                        }
                        return i;

                    });
                }
            }
            else
            {
                foreach (var j in jobectS)
                {
                    descriptor.Index<T>(i => i
                     .Index(IndexNameGenerator(j))
                     .Type(type)
                     .Document(j));
                }
            }
            var result = _Client.Bulk(descriptor);

            return result;
        }

        protected IBulkResponse BullkCreate<T>(string type,
            Func<T, string> IndexNameGenerator, IEnumerable<T> jobectS,
            Func<T, string> IdGenerator = null,
            Func<T, string> RoutingValue = null) where T : class
        {
            var descriptor = new BulkDescriptor();

            if (IdGenerator != null)
            {
                foreach (var j in jobectS)
                {
                    descriptor.Create<T>(i =>
                    {
                        i = i.Index(IndexNameGenerator(j))
                                .Type(type)
                                .Id(IdGenerator(j))
                                .Document(j);

                        if (RoutingValue != null)
                        {
                            i = i.Routing(RoutingValue(j));
                        }
                        return i;

                    });
                }
            }
            else
            {
                foreach (var j in jobectS)
                {
                    descriptor.Create<T>(i => i.Index(IndexNameGenerator(j))
                                                 .Type(type)
                                                 .Document(j));
                }
            }
            var result = _Client.Bulk(descriptor);

            return result;
        }

        protected ISearchResponse<T> GetSearch<T>(string indexName, string type,
            int pageSize, int pageNum,
            Func<SearchDescriptor<T>, SearchDescriptor<T>> SearchDescriptorFunc,
            List<FilterContainer> filters, string sortColumns = null) where T : class
        {
            try
            {
                pageNum = pageNum == 0 ? 1 : pageNum;

                var searchResults2 = _Client.Search<T>(s =>
                    {
                        var fff = s
                            .Fields(new string[] { ELASTIC_HIT__FIELD_NAME_SOURCE, ELASTIC_HIT__FIELD_NAME_TIMESTAMP })
                            .Indices(indexName)
                            .Type(type)
                            .From((pageNum - 1) * pageSize)
                            .Size(pageSize);

                        if (SearchDescriptorFunc != null)
                        {
                            fff = SearchDescriptorFunc(fff);
                        }

                        if (!string.IsNullOrEmpty(sortColumns))
                        {
                            var sortedColumns = sortColumns.Split(',');
                            foreach (var col in sortedColumns)
                            {
                                if (col.EndsWith("DESC"))
                                {
                                    fff = fff.SortDescending(col.Substring(0, col.IndexOf(' ')));
                                }
                                else if (col.EndsWith("ASCE"))
                                {
                                    fff = fff.SortAscending(col.Substring(0, col.IndexOf(' ')));
                                }
                            }
                        }

                        if (filters != null && filters.Count > 0)
                        {
                            fff = fff.Filter(f => f.And(filters.ToArray()));
                        }

                        return fff;
                    }
                );

                //used to get _timestamp value in record
                var _property = typeof(T)
                    .GetProperties()
                    .FirstOrDefault(p => p.PropertyType == typeof(DateTime)
                                        && p.GetCustomAttributes(typeof(System.ComponentModel.DescriptionAttribute), true)
                                            .OfType<System.ComponentModel.DescriptionAttribute>()
                                            .Any(a => a.Description == ELASTIC_TIMESTAMP_RECORD_PROPERTY)
                                        );
                if (_property != null)
                {
                    foreach (var item in searchResults2.Hits)
                    {
                        if (item.Fields.FieldValuesDictionary != null && item.Fields.FieldValuesDictionary.Any(f => f.Key == ELASTIC_HIT__FIELD_NAME_TIMESTAMP))
                        {
                            var _timestamp_ticks = item.Fields.FieldValues<long>(ELASTIC_HIT__FIELD_NAME_TIMESTAMP);
                            _property.SetValue(item.Source, new DateTime((_timestamp_ticks * TimeSpan.TicksPerMillisecond) + DATETIME_UNIX_1970_1JAN));
                        }

                    }
                }
                return searchResults2;

            }
            catch (Exception e)
            {
                throw e;
            }
        }

        protected IGetResponse<T> GetByID<T>(string indexName, string type, string id, string Routing = null) where T : class
        {
            try
            {
                return _Client.Get<T>(s =>
                    {
                        var ss = string.IsNullOrEmpty(Routing) ? s : s.Routing(Routing);

                        return ss.Index(indexName)
                                 .Type(type)
                                 .Id(id);
                    }
                );

            }
            catch (Exception e)
            {
                throw e;
            }



        }

        protected void DeleteIndex(string indexName)
        {
            _Client.DeleteIndex(indexName);
        }

        protected FilterContainer GetFilterRange<T>(DateTime? from, DateTime? to, string fieldName) where T : class
        {
            return GetFilterRange<T>(
                from.HasValue ? (long?)from.Value.Ticks : null,
                to.HasValue ? (long?)to.Value.Ticks : null,
                fieldName);
        }

        protected FilterContainer GetFilterRange<T>(long? from, long? to, string fieldName) where T : class
        {
            if (!from.HasValue && !to.HasValue)
            {
                return null;
            }
            else
            {
                if (from.HasValue && !to.HasValue)
                {
                    return new FilterDescriptor<T>()
                      .Range(pp => pp.OnField(fieldName)
                      .GreaterOrEquals(from.Value));
                }
                else if (!from.HasValue && to.HasValue)
                {
                    return new FilterDescriptor<T>()
                      .Range(pp => pp.OnField(fieldName)
                      .LowerOrEquals(to.Value));
                }
                else
                {
                    return new FilterDescriptor<T>()
                      .Range(pp => pp.OnField(fieldName)
                      .GreaterOrEquals(from.Value)
                      .LowerOrEquals(to.Value));
                }
            }
        }


        protected ISearchResponse<T> GetRecords<T>(
                          string BaseIndexName, string recordType,
                          string dateFieldName, long? fromTicks, long? toTicks, int PageSize, int PageNumber,
                          string RoutingFiled, string RoutingValue, string sortColumns = null,
                          IEnumerable<FilterContainer> AddFilters = null,
                          Func<SearchDescriptor<T>, SearchDescriptor<T>> SearchDescriptorFunc = null) where T : class
        {
            string Indices = BuildIndexName(BaseIndexName, fromTicks, toTicks);

            sortColumns = string.IsNullOrEmpty(sortColumns) ? String.Format("{0} ASCE", dateFieldName) : sortColumns;

            var _filters = new List<FilterContainer>();
            var rangeFilter = GetFilterRange<T>(fromTicks, toTicks, dateFieldName);
            if (rangeFilter != null)
            {
                _filters.Add(rangeFilter);
            }

            if (AddFilters != null)
            {
                _filters.AddRange(AddFilters);
            }

            if (!string.IsNullOrEmpty(RoutingFiled) && !string.IsNullOrEmpty(RoutingValue))
            {
                _filters.Add(new FilterDescriptor<T>().Term(RoutingFiled, RoutingValue));
            }

            var response = this.GetSearch<T>(
                                        Indices, recordType,
                                        PageSize, PageNumber,
                                        (s) =>
                                        {
                                            s = s.IgnoreUnavailable(true);
                                            if (SearchDescriptorFunc != null)
                                            {
                                                s = SearchDescriptorFunc(s);
                                            }
                                            if (!string.IsNullOrEmpty(RoutingValue))
                                            {
                                                return s.Routing(RoutingValue);
                                            }
                                            else
                                            {
                                                return s;
                                            }
                                        },
                                        _filters, sortColumns);

            return response;

        }

        #endregion

        #region common methods

        protected Models.HitRecord[] CreateCommonRecords<T>(IEnumerable<T> records2Index, string BaseIndexName, string TypeName) where T : class, Models.ICommonRecord
        {
            var bulkRespose = this.BullkCreate<T>(
                    TypeName,
                    r => BuildIndexName(BaseIndexName, r.RecordDate),
                    records2Index,
                    r => r.Identifier);

            return Convert(bulkRespose);
        }

        protected Models.HitRecord[] IndexCommonRecords<T>(IEnumerable<T> records2Index, string BaseIndexName, string TypeName) where T : class, Models.ICommonRecord
        {
            var bulkRespose = this.BullkIndex<T>(
                    TypeName,
                    r => BuildIndexName(BaseIndexName, r.RecordDate),
                    records2Index,
                    r => r.Identifier);

            return Convert(bulkRespose);
        }

        protected bool DeleteCommonRecordByID<T>(string BaseIndexName, string TypeName, T record) where T : class, Models.ICommonRecord
        {
            bool result = false;
            var respose = this.DeleteRecord(BuildIndexName(BaseIndexName, record.RecordDate),
                                                TypeName,
                                                record.Identifier);

            result = result || (respose.Found && respose.IsValid);

            return result;


        }

        #endregion

        #region IDisposable members

        public virtual void Dispose()
        {
            _Client = null;
        }

        #endregion
    }
}


