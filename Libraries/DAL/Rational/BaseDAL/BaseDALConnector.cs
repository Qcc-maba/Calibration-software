using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Xml;

namespace Maba.DAL.BaseDAL
{
    public enum DBOpenResults
    {
        Failed,
        WasAlreadyOpen,
        SuccessfullyOpened
    }

    public abstract class BaseDALConnector : IDisposable
    {
        #region CONSTANTS

        internal string ROW_NUMBER_COLUMN_NAME = "ROW_NUMBER";

        public const string PROVIDER_NAME_MYSQL = "MySql.Data.MySqlClient";
        public const string PROVIDER_NAME_MS_SQL = "System.Data.SqlClient";


        #endregion

        #region Properties

        public bool ThrowExceptions { get; set; }

        public bool KeepConnectionStates { get; set; }

        public bool IsDisposed { get; private set; }
        public Exception LastException { get; set; }
        public DbConnection ConnectionObj { get; private set; }
        public DbProviderFactory ProviderFactory { get; private set; }
        public int CommandTimeout { get; set; }

        public bool IsConnectionOpen
        {
            get
            {
                return (ConnectionObj != null)
                    && (ConnectionObj.State == ConnectionState.Open);
            }

        }
        #endregion

        #region ctor (s)

        private BaseDALConnector()
        {
            ThrowExceptions = false;
            KeepConnectionStates = true;
            CommandTimeout = 30;
        }

        protected BaseDALConnector(DbProviderFactory providerFactory, DbConnection connectionObj)
            : this()
        {
            ConnectionObj = connectionObj;
            ProviderFactory = providerFactory;
        }

        protected BaseDALConnector(DbProviderFactory providerFactory, string stringConnectionSectionName)
            : this()
        {
            var strings = System.Configuration.ConfigurationManager.ConnectionStrings;
            var connectionStringSettings = strings[stringConnectionSectionName];

            ProviderFactory = providerFactory;

            ConnectionObj = ProviderFactory.CreateConnection();
            ConnectionObj.ConnectionString = connectionStringSettings.ConnectionString;
        }

        #endregion

        #region private methods

        protected DbCommand BuildIntCommand(string storedProcName, IDataParameter[] parameters, out bool Result)
        {
            Result = false;
            try
            {
                bool subResult = false;
                DbCommand command = BuildQueryCommand(storedProcName, parameters, out subResult);

                if (subResult)
                {
                    if (!command.Parameters.Contains("@ReturnValue"))
                    {
                        var returnValueParameter = CreateParameter("@ReturnValue");
                        returnValueParameter.DbType = DbType.Int64;
                        returnValueParameter.Direction = ParameterDirection.ReturnValue;

                        command.Parameters.Add(returnValueParameter);
                    }

                    if (CommandTimeout > 0)
                        command.CommandTimeout = CommandTimeout;

                    Result = true;
                    return command;
                }
                else
                {
                    Result = false;
                    return null;
                }
            }
            catch (System.Exception e)
            {
                SetLastExceptionError(e);
                Result = false;
                return null;
            }
        }

        protected DbCommand BuildQueryCommand(string storedProcName, IDataParameter[] parameters, out bool Result)
        {
            Result = false;
            try
            {
                var command = ProviderFactory.CreateCommand();
                command.Connection = ConnectionObj;
                command.CommandText = storedProcName;
                command.CommandType = CommandType.StoredProcedure;

                if (parameters != null)
                {
                    command.Parameters.AddRange(parameters);
                    //foreach (IDataParameter parameter in parameters)
                    //{
                    //    command.Parameters.Add(parameter);
                    //}
                }

                Result = true;
                return command;
            }
            catch (System.Exception e)
            {
                SetLastExceptionError(e);
                Result = false;
                return null;
            }
        }

        #endregion

        #region protected methods

        protected void SetLastExceptionError(System.Exception e, bool ForceInvokeException)
        {
            this.LastException = e;

            if (ForceInvokeException)
            {
                VCT.Libs.Trace.Tracer.Error(e.Message);
            }
        }

        protected void SetLastExceptionError(Exception e)
        {
            SetLastExceptionError(e, this.ThrowExceptions || false);
        }

        #endregion

        #region static methods

        public virtual Reflection.PropertyAssignerAttribute.ConvertorDelegate HasFixedAssigner(Type dbColumnType, Type propertyType)
        {
            return null;
        }

        public virtual bool CheckTypesConverter(Type t, Type sourceType)
        {
            var converter = TypeDescriptor.GetConverter(t);

            return converter.CanConvertFrom(sourceType);
        }

        private static BaseDALConnector CreateConnector(string providerName, string connectionString)
        {
            var factory = DbProviderFactories.GetFactory(providerName);
            var connection = factory.CreateConnection();
            connection.ConnectionString = connectionString;

            //if (factory is MySql.Data.MySqlClient.MySqlClientFactory)
            //{
            //    return new MySQLConnector(factory, connection);
            //}
            //else
            if (factory is System.Data.SqlClient.SqlClientFactory)
            {
                return new MSSqlServer(factory, connection);
            }
            else
            {
                throw new NotSupportedException(String.Format("Not supported Factory {0}", factory.GetType()));
            }
        }

        public static BaseDALConnector Create(string stringConnectionSectionName)
        {
            var strings = System.Configuration.ConfigurationManager.ConnectionStrings;
            var connectionStringSettings = strings[stringConnectionSectionName];

            return CreateConnector(connectionStringSettings.ProviderName, connectionStringSettings.ConnectionString);
        }

        public static BaseDALConnector Create(string providerName, string stringConnection)
        {
            return CreateConnector(providerName, stringConnection);
        }

        #endregion

        #region IDisposable members

        public void Dispose()
        {
            if (IsDisposed)
                return;

            IsDisposed = true;

            Close();

            if (ConnectionObj != null)
            {
                try
                {
                    ConnectionObj.Dispose();
                }
                catch
                {
                }
            }
            ConnectionObj = null;
        }

        #endregion

        #region public Open / Close methods

        public virtual void Close(DBOpenResults LastStatus2Keep)
        {
            if (!KeepConnectionStates)
            {
                Close();
            }
            else
            {
                switch (LastStatus2Keep)
                {
                    case DBOpenResults.Failed:
                    case DBOpenResults.WasAlreadyOpen:
                        break;
                    default:
                    case DBOpenResults.SuccessfullyOpened:
                        Close();
                        break;
                }
            }
        }

        public virtual void Close()
        {
            if (ConnectionObj == null)
                return;

            try
            {
                if (ConnectionObj.State != ConnectionState.Closed)
                {
                    ConnectionObj.Close();
                }
            }
            catch (Exception e)
            {
                SetLastExceptionError(e, true);
            }
        }
        public virtual async Task<DBOpenResults> OpenAsync()
        {
            if (IsDisposed)
            {
                throw new ObjectDisposedException(GetType().Name);
            }

            try
            {
                if (ConnectionObj.State != ConnectionState.Open)
                {
                    await this.ConnectionObj.OpenAsync();
                    return DBOpenResults.SuccessfullyOpened;
                }

                return DBOpenResults.WasAlreadyOpen;
            }
            catch (Exception e)
            {
                SetLastExceptionError(e, true);
                return DBOpenResults.Failed;
            }
        }
        public virtual DBOpenResults Open()
        {
            if (IsDisposed)
            {
                throw new ObjectDisposedException(GetType().Name);
            }

            try
            {
                if (ConnectionObj.State != ConnectionState.Open)
                {
                    this.ConnectionObj.Open();
                    return DBOpenResults.SuccessfullyOpened;
                }

                return DBOpenResults.WasAlreadyOpen;
            }
            catch (Exception e)
            {
                SetLastExceptionError(e, true);
                return DBOpenResults.Failed;
            }
        }

        #endregion

        #region GetEntity / GetEntities

        public async Task<T[]> GetEntitiesAsync<T>(DataReaderEnumerator enumerator, params Reflection.IPropertyAssigner[] CustomPropertyAssigners) where T : new()
        {
            var _keepConnection = await this.OpenAsync();
            if (_keepConnection == DBOpenResults.Failed)
            {
                return new T[0];
            }

            try
            {
                Reflection.PropertyAssignerAttribute _PropertyAssigner = null;
                bool ignoreProperty = false;
                Type ColumnType = null;

                using (enumerator)
                {
                    await enumerator.OpenAsync();

                    if (!enumerator.CurrentRow.isValid)
                    {
                        return new T[0];
                    }

                    var typeProperties = typeof(T).GetProperties();
                    Reflection.PropertyAssignerAttribute[] properties = new Reflection.PropertyAssignerAttribute[typeProperties.Length];
                    bool foundProperty = false;
                    for (int pIndex = 0; pIndex < typeProperties.Length; pIndex++)
                    {
                        var p = typeProperties[pIndex];

                        //reset every property
                        ignoreProperty = false;

                        #region try get _PropertyAssigner for this property

                        //custom assigner in high priority
                        _PropertyAssigner = CustomPropertyAssigners == null ? null : CustomPropertyAssigners
                                                                                                .OfType<Reflection.PropertyAssignerAttribute>()
                                                                                                .FirstOrDefault(c => c.CustomPropertyName == p.Name);

                        if (_PropertyAssigner == null)
                        {
                            foreach (var attr in p.GetCustomAttributes(typeof(Reflection.IPropertyAssigner), true))
                            {
                                if (attr is Reflection.PropertyAssignerIgnoreAttribute)
                                {
                                    ignoreProperty = true;
                                    break;
                                }

                                if (attr is Reflection.PropertyAssignerAttribute)
                                {
                                    _PropertyAssigner = attr as Reflection.PropertyAssignerAttribute;
                                }
                            }

                            if (ignoreProperty)
                                continue;
                        }

                        if (_PropertyAssigner != null)
                        {
                            _PropertyAssigner.Property = p;
                            _PropertyAssigner.CustomPropertyName = p.Name;
                        }

                        #endregion

                        #region match column to this property

                        for (int i = 0; i < enumerator.CurrentRow.Columns.Length; i++)
                        {
                            ColumnType = enumerator.CurrentRow.DataReader.GetFieldType(i);

                            if (_PropertyAssigner != null)
                            {
                                #region property with assigner (as attribute/custom)

                                if ((_PropertyAssigner.DBColumnName ?? _PropertyAssigner.CustomPropertyName ?? p.Name) == enumerator.CurrentRow.Columns[i])
                                {
                                    if (_PropertyAssigner.HasConvertor)
                                    {
                                        if (_PropertyAssigner.CustomValueConverter != null)
                                        {

                                        }
                                        else if (!String.IsNullOrEmpty(_PropertyAssigner.TypeConvertFunctionName))
                                        {
                                            _PropertyAssigner.GetConvertFunction<T>();
                                        }

                                        _PropertyAssigner.ColumnIndex = i;
                                        properties[pIndex] = _PropertyAssigner;
                                    }
                                    else if (ColumnType == p.PropertyType
                                        || ColumnType == Nullable.GetUnderlyingType(p.PropertyType)
                                        || CheckTypesConverter(p.PropertyType, ColumnType)
                                        || p.PropertyType.IsAssignableFrom(ColumnType))
                                    {
                                        _PropertyAssigner.ColumnIndex = i;
                                        properties[pIndex] = _PropertyAssigner;
                                    }
                                }

                                #endregion
                            }
                            else
                            {
                                #region property without assigner

                                if (p.Name == enumerator.CurrentRow.Columns[i])
                                {
                                    if (ColumnType == p.PropertyType
                                        || ColumnType == Nullable.GetUnderlyingType(p.PropertyType)
                                        || CheckTypesConverter(p.PropertyType, ColumnType)
                                        || p.PropertyType.IsAssignableFrom(ColumnType))
                                    {
                                        properties[pIndex] = new Reflection.PropertyAssignerAttribute()
                                        {
                                            ColumnIndex = i,
                                            Property = p,
                                            DBColumnName = enumerator.CurrentRow.Columns[i]
                                        };
                                    }
                                    else
                                    {
                                        var fixedValueConverter = HasFixedAssigner(ColumnType, p.PropertyType);
                                        if (fixedValueConverter != null)
                                        {
                                            properties[pIndex] = new Reflection.PropertyAssignerAttribute()
                                            {
                                                ColumnIndex = i,
                                                Property = p,
                                                DBColumnName = enumerator.CurrentRow.Columns[i],
                                                CustomValueConverter = fixedValueConverter
                                            };
                                        }
                                        else
                                        {
                                            throw new Reflection.IncompatibleColumnTypeException()
                                            {
                                                DbColumnName = enumerator.CurrentRow.Columns[i],
                                                DbColumnType = ColumnType,
                                                DbColumnExpectedType = p.PropertyType
                                            };
                                        }
                                    }
                                }

                                #endregion
                            }

                            if (properties[pIndex] != null)
                            {
                                foundProperty = true;
                                break;
                            }
                        }

                        #endregion
                    }

                    if (!foundProperty)
                    {
                        return new T[0];
                    }

                    #region print values

                    T value;
                    bool hasValue = false;
                    var list = new List<T>();

                    while (await enumerator.ReadAsync())
                    {
                        value = new T();
                        hasValue = false;

                        foreach (var p in properties)
                        {
                            if (p == null || p.Property.SetMethod == null)
                                continue;

                            hasValue = hasValue || !enumerator.CurrentRow.DataReader.IsDBNull(p.ColumnIndex);
                            p.Assign(enumerator.CurrentRow.DataReader, value);
                        }

                        if (hasValue)
                        {
                            list.Add(value);
                        }
                    }

                    return list.ToArray();

                    #endregion
                }
            }
            finally
            {
                if (_keepConnection == DBOpenResults.SuccessfullyOpened)
                    Close();
            }
        }


        public IEnumerable<T> GetEntities<T>(DataReaderEnumerator enumerator,
            params Reflection.IPropertyAssigner[] CustomPropertyAssigners) where T : new()
        {
            var _keepConnection = this.Open();
            if (_keepConnection == DBOpenResults.Failed)
                yield break;

            try
            {
                Reflection.PropertyAssignerAttribute _PropertyAssigner = null;
                bool ignoreProperty = false;
                Type ColumnType = null;

                using (enumerator)
                {
                    enumerator.Open();

                    if (!enumerator.CurrentRow.isValid)
                    {
                        yield break;
                    }

                    var typeProperties = typeof(T).GetProperties();
                    Reflection.PropertyAssignerAttribute[] properties = new Reflection.PropertyAssignerAttribute[typeProperties.Length];
                    bool foundProperty = false;
                    for (int pIndex = 0; pIndex < typeProperties.Length; pIndex++)
                    {
                        var p = typeProperties[pIndex];

                        //reset every property
                        ignoreProperty = false;

                        #region try get _PropertyAssigner for this property

                        //custom assigner in high priority
                        _PropertyAssigner = CustomPropertyAssigners == null ? null : CustomPropertyAssigners
                                                                                                .OfType<Reflection.PropertyAssignerAttribute>()
                                                                                                .FirstOrDefault(c => c.CustomPropertyName == p.Name);

                        if (_PropertyAssigner == null)
                        {
                            foreach (var attr in p.GetCustomAttributes(typeof(Reflection.IPropertyAssigner), true))
                            {
                                if (attr is Reflection.PropertyAssignerIgnoreAttribute)
                                {
                                    ignoreProperty = true;
                                    break;
                                }

                                if (attr is Reflection.PropertyAssignerAttribute)
                                {
                                    _PropertyAssigner = attr as Reflection.PropertyAssignerAttribute;
                                }
                            }

                            if (ignoreProperty)
                                continue;
                        }

                        if (_PropertyAssigner != null)
                        {
                            _PropertyAssigner.Property = p;
                            _PropertyAssigner.CustomPropertyName = p.Name;
                        }

                        #endregion

                        #region match column to this property

                        for (int i = 0; i < enumerator.CurrentRow.Columns.Length; i++)
                        {
                            ColumnType = enumerator.CurrentRow.DataReader.GetFieldType(i);

                            if (_PropertyAssigner != null)
                            {
                                #region property with assigner (as attribute/custom)

                                if ((_PropertyAssigner.DBColumnName ?? _PropertyAssigner.CustomPropertyName ?? p.Name) == enumerator.CurrentRow.Columns[i])
                                {
                                    if (_PropertyAssigner.HasConvertor)
                                    {
                                        if (_PropertyAssigner.CustomValueConverter != null)
                                        {

                                        }
                                        else if (!String.IsNullOrEmpty(_PropertyAssigner.TypeConvertFunctionName))
                                        {
                                            _PropertyAssigner.GetConvertFunction<T>();
                                        }

                                        _PropertyAssigner.ColumnIndex = i;
                                        properties[pIndex] = _PropertyAssigner;
                                    }
                                    else if (ColumnType == p.PropertyType
                                        || ColumnType == Nullable.GetUnderlyingType(p.PropertyType)
                                        || CheckTypesConverter(p.PropertyType, ColumnType)
                                        || p.PropertyType.IsAssignableFrom(ColumnType))
                                    {
                                        _PropertyAssigner.ColumnIndex = i;
                                        properties[pIndex] = _PropertyAssigner;
                                    }
                                }

                                #endregion
                            }
                            else
                            {
                                #region property without assigner

                                if (p.Name == enumerator.CurrentRow.Columns[i])
                                {
                                    if (ColumnType == p.PropertyType
                                        || ColumnType == Nullable.GetUnderlyingType(p.PropertyType)
                                        || CheckTypesConverter(p.PropertyType, ColumnType)
                                        || p.PropertyType.IsAssignableFrom(ColumnType))
                                    {
                                        properties[pIndex] = new Reflection.PropertyAssignerAttribute()
                                        {
                                            ColumnIndex = i,
                                            Property = p,
                                            DBColumnName = enumerator.CurrentRow.Columns[i]
                                        };
                                    }
                                    else
                                    {
                                        var fixedValueConverter = HasFixedAssigner(ColumnType, p.PropertyType);
                                        if (fixedValueConverter != null)
                                        {
                                            properties[pIndex] = new Reflection.PropertyAssignerAttribute()
                                            {
                                                ColumnIndex = i,
                                                Property = p,
                                                DBColumnName = enumerator.CurrentRow.Columns[i],
                                                CustomValueConverter = fixedValueConverter
                                            };
                                        }
                                        else
                                        {
                                            throw new Reflection.IncompatibleColumnTypeException()
                                            {
                                                DbColumnName = enumerator.CurrentRow.Columns[i],
                                                DbColumnType = ColumnType,
                                                DbColumnExpectedType = p.PropertyType
                                            };
                                        }
                                    }
                                }

                                #endregion
                            }

                            if (properties[pIndex] != null)
                            {
                                foundProperty = true;
                                break;
                            }
                        }

                        #endregion
                    }

                    if (!foundProperty)
                    {
                        yield break;
                    }

                    #region print values

                    T value;
                    bool hasValue = false;
                    while (enumerator.Read())
                    {
                        value = new T();
                        hasValue = false;

                        foreach (var p in properties)
                        {
                            if (p == null || p.Property.SetMethod == null)
                                continue;

                            hasValue = hasValue || !enumerator.CurrentRow.DataReader.IsDBNull(p.ColumnIndex);
                            p.Assign(enumerator.CurrentRow.DataReader, value);
                        }

                        if (hasValue)
                        {
                            yield return value;
                        }
                    }

                    #endregion
                }
            }
            finally
            {
                if (_keepConnection == DBOpenResults.SuccessfullyOpened)
                    Close();
            }
        }

        public T GetEntity<T>(DataReaderEnumerator enumerator,
            params Reflection.IPropertyAssigner[] CustomPropertyAssigners) where T : new()
        {
            var results = GetEntities<T>(enumerator, CustomPropertyAssigners)
                .ToArray();

            if (results == null || results.Length == 0)
            {
                return default(T);
            }
            else
            {
                return results[0];
            }
        }

        #endregion

        #region protected/abstract virtual methods

        #region Create Parameters

        public DbParameter CreateNullParameter(string Name, Type ParameterType)
        {
            var p = CreateParameter(Name);
            if (ParameterType == typeof(byte[]))
            {
                p.Value = new byte[0];
                var type = p.DbType;
                p.Value = DBNull.Value;
                p.DbType = type;
                p.Size = -1;
            }
            else
            {
                var val = Activator.CreateInstance(ParameterType, false);
                p.Value = val;
                var type = p.DbType;
                p.Value = DBNull.Value;
                p.DbType = type;
            }
            return p;
        }

        public DbParameter CreateParameter(string Name)
        {
            return CreateParameter(Name, null);
        }

        public DbParameter CreateParameter<T>(string Name, Nullable<T> value) where T : struct
        {
            if (!value.HasValue)
            {
                return CreateNullParameter(Name, typeof(T));
            }
            else
            {
                return CreateParameter(Name, value.Value);
            }
        }

        public DbParameter CreateParameter(string Name, object value)
        {
            var p = ProviderFactory.CreateParameter();
            p.ParameterName = Name;
            if (value != null)
                p.Value = value;
            else
            {
                p.SourceColumnNullMapping = true;
                p.Value = DBNull.Value;
            }
            return p;
        }

        public DbParameter CreateOutParameter(string Name, object value)
        {
            var p = ProviderFactory.CreateParameter();
            p.ParameterName = Name;
            p.Direction = ParameterDirection.Output;
            if (value != null)
                p.Value = value;
            else
            {
                p.SourceColumnNullMapping = true;
                p.Value = DBNull.Value;
            }
            return p;
        }

        #endregion

        #region General Stataments

        public void WrapDataReader(DbDataReader reader, Action<DbDataReader> action)
        {
            try
            {
                if (action != null)
                {
                    action(reader);
                }
            }
            catch (Exception e)
            {
                throw e;
            }
            finally
            {
                DataReaderEnumerator.HandleDataReader(reader);
            }
        }
        /// <summary>
        /// Runs as Procedure. No Paging / Ordering.
        /// </summary>
        public DataReaderEnumerator CreateStatementEnumerator(string Statement, params IDataParameter[] parameters)
        {
            var enumerator = new DataReaderEnumerator()
            {
                RunProcedureHandler = (out bool result) =>
                {
                    return this.RunStatement(Statement, parameters, out result);
                }
            };
            return enumerator;
        }

        public DbDataReader RunStatement(string StatementSentence, IDataParameter[] parameters, out bool Result)
        {
            Result = false;

            try
            {
                if (!IsConnectionOpen && Open() == DBOpenResults.Failed)
                    return null;

                bool subResult = false;

                DbCommand command = BuildQueryCommand(StatementSentence, parameters, out subResult);
                if (subResult)
                {
                    command.CommandType = CommandType.Text;

                    var returnReader = command.ExecuteReader();
                    //if DbConnectionObj will be closed here, no data can be read...
                    //!!! DON'T !!! Close();  !!! DON'T !!!         
                    Result = true;

                    return returnReader;
                }
                else
                {
                    Result = false;
                    return null;
                }
            }
            catch (System.Exception e)
            {
                SetLastExceptionError(e);
                Result = false;
                return null;
            }
        }

        #endregion

        #region Procedures

        #region XML Procedures

        public abstract XmlReader RunXMLProcedure(string StoredProcedureName, IDataParameter[] parameters, out bool Result);

        #endregion

        #region Enumertors

        public DataReaderEnumerator CreateProcedureEnumerator(string SPName, IDataParameter[] parameters)
        {
            var enumerator = new DataReaderEnumerator()
            {
                SPName = SPName,
                Parameters = parameters,
                RunProcedureHandler = (out bool result) =>
                {
                    return RunProcedure(SPName, parameters, out result);
                }
            };
            return enumerator;
        }

        public DataReaderEnumerator CreateProcedureAsyncEnumerator(string SPName, IDataParameter[] parameters)
        {
            var enumerator = new DataReaderEnumerator()
            {
                SPName = SPName,
                Parameters = parameters,
                RunProcedureHandlerAsync = async () =>
                {
                    return await RunProcedureAsync(SPName, parameters);
                }
            };
            return enumerator;
        }

        public IEnumerable<DataReaderRow> GetProcedureEnumerator(string SPName, IDataParameter[] parameters)
        {
            using (var enumerator = CreateProcedureEnumerator(SPName, parameters))
            {
                while (enumerator.Read())
                {
                    yield return enumerator.CurrentRow;
                }
            }
        }

        #endregion
        public DbDataReader RunProcedure(string StoredProcedureName, IDataParameter[] parameters)
        {
            DBOpenResults firstConnectionState = DBOpenResults.Failed;
            try
            {
                firstConnectionState = Open();

                if (!IsConnectionOpen && firstConnectionState == DBOpenResults.Failed)
                    return null;

                bool subResult = false;

                DbCommand command = BuildQueryCommand(StoredProcedureName, parameters, out subResult);
                if (subResult)
                {
                    command.CommandType = CommandType.StoredProcedure;
                    var returnReader = command.ExecuteReader();

                    //if DbConnectionObj will be closed here, no data can be read...
                    //!!! DON'T !!! Close();  !!! DON'T !!!         
                    return returnReader;
                }
                else
                {
                    return null;
                }
            }
            catch (System.Exception e)
            {
                SetLastExceptionError(e);
                return null;
            }
        }


        public async Task<DbDataReader> RunProcedureAsync(string storedProcedureName, IDataParameter[] parameters)
        {
            Console.WriteLine("Starting RunProcedureAsync");

            try
            {
                // Set a timeout for the entire operation
                using (var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30)))
                {
                    Console.WriteLine("Attempting to open connection...");

                    // Open connection with timeout
                    var openTask = OpenAsync();
                    if (await Task.WhenAny(openTask, Task.Delay(5000, cts.Token)) != openTask)
                    {
                        Console.WriteLine("Connection timeout after 5 seconds");
                        return null;
                    }

                    var firstConnectionState = await openTask;
                    Console.WriteLine($"Connection state: {firstConnectionState}");

                    if (!IsConnectionOpen && firstConnectionState == DBOpenResults.Failed)
                    {
                        Console.WriteLine("Connection failed to open");
                        return null;
                    }

                    bool subResult = false;
                    Console.WriteLine("Building command...");
                    using (DbCommand command = BuildQueryCommand(storedProcedureName, parameters, out subResult))
                    {
                        if (!subResult)
                        {
                            Console.WriteLine("Failed to build command");
                            return null;
                        }

                        command.CommandType = CommandType.StoredProcedure;
                        command.CommandTimeout = CommandTimeout; // 30 seconds timeout

                        Console.WriteLine("Executing command...");
                        try
                        {
                            // Execute with timeout
                            var readerTask = command.ExecuteReaderAsync(cts.Token);
                            var timeoutTask = Task.Delay(TimeSpan.FromSeconds(CommandTimeout), cts.Token);

                            var completedTask = await Task.WhenAny(readerTask, timeoutTask);
                            if (completedTask == timeoutTask)
                            {
                                Console.WriteLine("Command execution timed out");
                                return null;
                            }

                            var reader = await readerTask;
                            Console.WriteLine("Command executed successfully");
                            return reader;
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"Error executing command: {ex.Message}");
                            throw;
                        }
                    }
                }
            }
            catch (Exception e)
            {
                Console.WriteLine($"Error in RunProcedureAsync: {e.Message}");
                Console.WriteLine($"Stack trace: {e.StackTrace}");
                SetLastExceptionError(e);
                return null;
            }
        }
        public DbDataReader RunProcedure(string StoredProcedureName, IDataParameter[] parameters, out bool Result)
        {
            Result = false;
            DBOpenResults firstConnectionState = DBOpenResults.Failed;
            try
            {
                firstConnectionState = Open();

                if (!IsConnectionOpen && firstConnectionState == DBOpenResults.Failed)
                    return null;

                bool subResult = false;

                DbCommand command = BuildQueryCommand(StoredProcedureName, parameters, out subResult);
                if (subResult)
                {
                    command.CommandType = CommandType.StoredProcedure;

                    var returnReader = command.ExecuteReader();
                    //if DbConnectionObj will be closed here, no data can be read...
                    //!!! DON'T !!! Close();  !!! DON'T !!!         
                    Result = true;
                    return returnReader;
                }
                else
                {
                    Result = false;
                    return null;
                }
            }
            catch (System.Exception e)
            {
                SetLastExceptionError(e);
                Result = false;
                return null;
            }
        }

        public long GetProcedureResultInt64(string storedProcName, IDataParameter[] parameters, out int rowsAffected, out bool Result)
        {
            Result = false;
            rowsAffected = 0;
            DBOpenResults firstConnectionState = DBOpenResults.Failed;

            try
            {
                long result = -1;
                bool subResult = false;

                firstConnectionState = Open();

                if (!IsConnectionOpen && firstConnectionState == DBOpenResults.Failed)
                    return -1;

                DbCommand command = BuildIntCommand(storedProcName, parameters, out subResult);
                if (subResult)
                {
                    rowsAffected = command.ExecuteNonQuery();
                    if (command.Parameters["@ReturnValue"].Value != DBNull.Value)
                    {
                        result = Convert.ToInt64(command.Parameters["@ReturnValue"].Value);
                    }
                    else
                    {
                        result = -1;
                    }

                    Result = true;
                    return result;
                }
                else
                {
                    rowsAffected = -1;
                    Result = false;
                    return -1;
                }
            }
            catch (System.Exception e)
            {
                SetLastExceptionError(e);
                Result = false;
                rowsAffected = -1;
                return -1;
            }
            finally
            {
                Close(firstConnectionState);
            }
        }

        public int GetProcedureResultInt32(string storedProcName, IDataParameter[] parameters, out int rowsAffected, out bool Result)
        {

            long result = GetProcedureResultInt64(storedProcName, parameters, out rowsAffected, out Result);

            if (result > int.MaxValue)
            {
                Result = false;
                return int.MaxValue;
            }
            else
                return (int)result;
        }

        public DataSet RunProcedure(string storedProcName, IDataParameter[] parameters, string tableName, out bool Result)
        {

            Result = false;
            DBOpenResults firstConnectionState = DBOpenResults.Failed;

            try
            {
                firstConnectionState = Open();
                if (!IsConnectionOpen && firstConnectionState == DBOpenResults.Failed)
                    return null;

                DataSet dataSet = new DataSet();
                bool subResult = false;

                var dataAdapter = ProviderFactory.CreateDataAdapter();
                dataAdapter.SelectCommand = BuildQueryCommand(storedProcName, parameters, out subResult);
                if (subResult)
                {
                    dataAdapter.Fill(dataSet, tableName);
                    Result = true;
                    return dataSet;
                }
                else
                {
                    Result = false;
                    return null;
                }
            }
            catch (System.Exception e)
            {
                SetLastExceptionError(e);
                Result = false;
                return null;
            }
            finally
            {
                if (KeepConnectionStates)
                    Close(firstConnectionState);
            }
        }

        public void RunProcedure(string storedProcName, IDataParameter[] parameters, DataSet dataSet, string tableName, out bool Result)
        {
            Result = false;
            DBOpenResults firstConnectionState = DBOpenResults.Failed;

            try
            {
                firstConnectionState = Open();
                if (!IsConnectionOpen && firstConnectionState == DBOpenResults.Failed)
                    return;

                bool subResult = false;

                var dataAdapter = ProviderFactory.CreateDataAdapter();
                dataAdapter.SelectCommand = BuildQueryCommand(storedProcName, parameters, out subResult);
                if (subResult)
                {
                    dataAdapter.Fill(dataSet, tableName);
                    Result = true;
                }
                else
                {
                    Result = false;
                }
            }
            catch (System.Exception e)
            {
                SetLastExceptionError(e);
                Result = false;
            }
            finally
            {
                if (KeepConnectionStates)
                    Close(firstConnectionState);
            }
        }

        #endregion

        #region Table

        protected virtual string BuildTableStatement(string TableName, string[] OrderByColumns)
        {
            string statement = null;

            if (OrderByColumns != null && OrderByColumns.Length > 0)
            {
                string orderByClause = "";

                foreach (var col in OrderByColumns)
                {
                    orderByClause += col + ",";
                }
                orderByClause = orderByClause.Substring(0, orderByClause.Length - 1);

                statement = String.Format("SELECT * from {0} ORDER BY {1}",
                                            TableName,
                                            orderByClause);
            }
            else
            {
                statement = "SELECT * FROM " + TableName;
            }

            return statement;
        }

        public virtual DataReaderEnumerator CreateTableEnumerator(string TableName, string[] OrderByColumns)
        {
            var enumerator = new DataReaderEnumerator()
            {
                RunProcedureHandler = (out bool result) =>
                {
                    return RunStatement(BuildTableStatement(TableName, OrderByColumns), null, out result);
                }
            };

            return enumerator;
        }

        #endregion

        #region Functions

        protected virtual string BuildScalarFunctionStatement(string FunctionName, System.Data.IDataParameter[] parameters)
        {
            if (parameters != null && parameters.Length > 0)
            {
                string parametersSTR = "";

                if (parameters != null && parameters.Length > 0)
                {
                    foreach (var p in parameters)
                    {
                        parametersSTR += "@" + p.ParameterName + ",";
                    }
                    parametersSTR = parametersSTR.Substring(0, parametersSTR.Length - 1);
                }

                return String.Format("SELECT {0}({1})", FunctionName, parametersSTR);
            }
            else
            {
                return String.Format("SELECT {0}()", FunctionName);
            }
        }

        protected virtual string BuildTableFunctionStatement(string FunctionName, string[] OrderByColumns, System.Data.IDataParameter[] parameters)
        {
            string statement = null;

            if (parameters != null && parameters.Length > 0)
            {
                string parametersSTR = "";

                if (parameters != null && parameters.Length > 0)
                {
                    foreach (var p in parameters)
                    {
                        parametersSTR += "@" + p.ParameterName + ",";
                    }
                    parametersSTR = parametersSTR.Substring(0, parametersSTR.Length - 1);
                }

                statement = String.Format("{0}({1})", FunctionName, parametersSTR);
            }
            else
            {
                statement = String.Format("{0}()", FunctionName);
            }

            if (OrderByColumns != null && OrderByColumns.Length > 0)
            {
                string orderByClause = "";

                foreach (var col in OrderByColumns)
                {
                    orderByClause += col + ",";
                }
                orderByClause = orderByClause.Substring(0, orderByClause.Length - 1);

                statement = String.Format("SELECT * from {0} ORDER BY {1}",
                                            statement,
                                            orderByClause);
            }
            else
            {
                statement = "SELECT * FROM " + statement;
            }

            return statement;
        }

        protected virtual DbDataReader CreateFunctionDataReader(string ScalarFunctionName, System.Data.IDataParameter[] parameters, out bool Result)
        {
            Result = false;
            try
            {
                return RunStatement(BuildTableFunctionStatement(ScalarFunctionName, null, parameters), parameters, out Result);
            }
            catch (System.Exception e)
            {
                SetLastExceptionError(e);
                Result = false;
                return null;
            }
        }

        #region Scalar Function

        public T RunScalarFunctionResult<T>(string ScalarFunctionName, T DefaultValue, out bool Result, params IDataParameter[] parameters)
        {
            Result = false;
            DBOpenResults firstConnectionState = DBOpenResults.Failed;
            try
            {
                firstConnectionState = Open();

                if (!IsConnectionOpen && firstConnectionState == DBOpenResults.Failed)
                    return DefaultValue;

                var reader = RunStatement(BuildScalarFunctionStatement(ScalarFunctionName, parameters), parameters, out Result);

                while (reader.Read())
                {
                    return (T)reader.GetValue(0);
                }

                DataReaderEnumerator.HandleDataReader(reader);
            }
            catch (System.Exception e)
            {
                SetLastExceptionError(e);
                Result = false;
            }
            finally
            {
                Close(firstConnectionState);
            }

            return DefaultValue;
        }

        public T RunScalarFunctionResult<T>(string ScalarFunctionName, out bool Result, params IDataParameter[] parameters)
        {
            return RunScalarFunctionResult(ScalarFunctionName, default(T), out Result, parameters);
        }

        #endregion

        #region Table Function

        public virtual DataReaderEnumerator CreateTableFunctionEnumerator(string TableFunctionName, params IDataParameter[] parameters)
        {
            return CreateTableFunctionEnumerator(TableFunctionName, null, parameters);
        }

        public virtual DataReaderEnumerator CreateTableFunctionEnumerator(string TableFunctionName, string[] OrderByColumns, params IDataParameter[] parameters)
        {
            var enumerator = new DataReaderEnumerator()
            {
                RunProcedureHandler = (out bool result) =>
                {
                    return RunStatement(BuildTableFunctionStatement(TableFunctionName, OrderByColumns, parameters), parameters, out result);
                }
            };

            return enumerator;
        }

        #endregion

        #endregion

        #endregion

    }
}
