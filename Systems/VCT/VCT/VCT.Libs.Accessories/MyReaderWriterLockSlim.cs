using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Maba.VCT.Accessories
{
    public class MyReaderWriterLockSlim<T> : ReaderWriterLockSlim where T : class, new()
    {
        #region Members

        private T LockedItem = null;

        #endregion

        #region ctors(s)

        public MyReaderWriterLockSlim(T item)
        {
            LockedItem = item;
        }
        public MyReaderWriterLockSlim()
        {
            LockedItem = new T();
        }

        #endregion

        #region Public methods

        public void MyReadLock(Action<T> MethodName)
        {
            EnterReadLock();

            try
            {
                MethodName(LockedItem);
            }
            catch
            {
            }

            finally
            {
                ExitReadLock();
            }
        }

        public void MyWriteLock(Action<T> MethodName)
        {
            EnterWriteLock();

            try
            {
                MethodName(LockedItem);
            }
            catch
            {
            }

            finally
            {
                ExitWriteLock();
            }
        }

        public void MyUpdateLock(Action<T> MethodName)
        {
            EnterUpgradeableReadLock();

            try
            {
                MethodName(LockedItem);
            }
            catch
            {
            }

            finally
            {
                ExitUpgradeableReadLock();
            }
        }

        #endregion
    }
}
