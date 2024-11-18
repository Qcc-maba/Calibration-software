using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Data.Common;

using System.Data;
using System.Threading.Tasks;

namespace Maba.DAL.BaseDAL
{
    public class DataReaderEnumerator : IDisposable
    {
        #region Properties

        public DataReaderRow CurrentRow { get; private set; }

        public bool LastResult { get; private set; }
        internal delegate DbDataReader RunProcedureDelegate(out bool Result);
        internal delegate Task<DbDataReader> RunProcedureAsyncDelegate();

        internal RunProcedureDelegate RunProcedureHandler;
        internal RunProcedureAsyncDelegate RunProcedureHandlerAsync;

        public bool IsDisposed { get; private set; }




        public string SPName { get; internal set; }
        public IDataParameter[] Parameters { get; internal set; }

        #endregion

        #region constructors

        public DataReaderEnumerator()
        {
            IsDisposed = false;
        }

        #endregion

        #region static

        public static void HandleDataReader(DbDataReader reader)
        {
            if (reader != null && !reader.IsClosed)
            {
                reader.Close();
            }
        }

        #endregion

        #region public method

        public void Close()
        {
            Dispose();
        }

        public void Open()
        {
            if (CurrentRow == null)
            {
                bool result = false;
                DbDataReader reader = RunProcedureHandler(out result);

                if (!result || reader == null)
                {
                    HandleDataReader(reader);
                    CurrentRow = new EmptyDataReaderRow();
                }
                else
                {
                    CurrentRow = new DataReaderRow(reader);
                }
            }
        }

        public async Task OpenAsync()
        {
            if (CurrentRow == null)
            {
                DbDataReader reader = await RunProcedureHandlerAsync();

                if (reader == null)
                {
                    HandleDataReader(reader);
                    CurrentRow = new EmptyDataReaderRow();
                }
                else
                {
                    CurrentRow = new DataReaderRow(reader);
                }
            }
        }

        public bool Read()
        {
            Open();

            LastResult =
                !IsDisposed
                            && CurrentRow != null
                            && CurrentRow.isValid
                            && CurrentRow.DataReader != null
                            && CurrentRow.DataReader.HasRows;

            if (LastResult)
            {
                var read = CurrentRow.DataReader.Read();

                if (read)
                {
                    CurrentRow.RowIndex = CurrentRow.RowIndex.HasValue ? CurrentRow.RowIndex++ : 0;
                }
                else
                {
                    LastResult = false;
                }
            }
            else
            {
                Dispose();
            }

            return LastResult;
        }

        public async Task<bool> ReadAsync()
        {
            Open();

            LastResult =
                !IsDisposed
                            && CurrentRow != null
                            && CurrentRow.isValid
                            && CurrentRow.DataReader != null
                            && CurrentRow.DataReader.HasRows;

            if (LastResult)
            {
                var read = await CurrentRow.DataReader.ReadAsync();

                if (read)
                {
                    CurrentRow.RowIndex = CurrentRow.RowIndex.HasValue ? CurrentRow.RowIndex++ : 0;
                }
                else
                {
                    LastResult = false;
                }
            }
            else
            {
                Dispose();
            }

            return LastResult;
        }

        #endregion

        #region IDisposable Members

        public void Dispose()
        {
            IsDisposed = true;

            if (CurrentRow != null)
            {
                HandleDataReader(CurrentRow.DataReader);
                CurrentRow = null;
            }
        }

        #endregion
    }
}
