using StackExchange.Redis;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.InMemoryCache.StackExchange.Redis
{
    public class StackExchangeRedisClient : IMemoryCacheConnector
    {
        #region members

        private ConnectionMultiplexer muxer = null;

        #endregion

        #region ctor

        public StackExchangeRedisClient(string address = null)
        {
            var host = address ?? "localhost:6379";
            muxer = ConnectionMultiplexer.Connect($"{host},resolvedns=1");

            //muxer = ConnectionMultiplexer.Connect("localhost,resolvedns=1");

        }

        #endregion

        #region IMemoryCacheConnector members

        public async Task<string> GetKeyAsync(string key)
        {
            var db = muxer.GetDatabase();
            var val = await db.StringGetAsync(key);

            return val.HasValue ? val.ToString() : null;
        }

        public async Task<bool> SetKeyAsync(string key, string value)
        {
            var db = muxer.GetDatabase();
            return await db.StringSetAsync(key, value, null, When.Always);
        }

        public async Task<bool> SetHashKeyAsync(string key, string hashKey, string value)
        {
            var db = muxer.GetDatabase();

            var result = await db.HashSetAsync(key, hashKey, value);

            return result;
        }

        public async Task<bool> SetHashKeysAsync(string key, KeyValuePair<string, string>[] hashKeys)
        {
            var db = muxer.GetDatabase();

            var entries = hashKeys
                .Select(k => new HashEntry(k.Key, k.Value))
                .ToArray();

            await db.HashSetAsync(key, entries);

            return true;
        }

        public async Task<string> GetHashKeyAsync(string key, string hashKey)
        {
            var db = muxer.GetDatabase();

            var hashKeyValue = await db.HashGetAsync(key, hashKey);

            return hashKeyValue;
        }

        public async Task<KeyValuePair<string, string>[]> GetHashAllKeysAsync(string key)
        {
            var db = muxer.GetDatabase();

            var t = Task.Run<HashEntry[]>(() =>
            {
                var keyValues = db.HashGetAll(key);
                return keyValues;
            });

            var keys = await t;

            return keys
                .Select(k => new KeyValuePair<string, string>(k.Key, k.Value))
                .ToArray();
        }

        #endregion

        #region public methods


        public int CalcHashSlot(string key)
        {
            return muxer.HashSlot(key);
        }

        public byte[] PrepareAndLoadScript(string script)
        {
            var s = LuaScript.Prepare(script);

            var db = muxer.GetDatabase();

            var d = s.Load(muxer.GetServer(muxer.GetEndPoints()[0]));
            return d.Hash;
        }

        //public byte[] LoadScript(string owenrshipKey, int OwnerNumber)
        //{
        //    string script = String.Format("if redis.call('get', '{0}') == nil || redis.call('get', '{0}') == '{number}' then "
        //        + "return redis.call('set', '{0}', '{number}', 10) "
        //        + "else "
        //        + "return 'XX' "
        //        + "end;", owenrshipKey, OwnerNumber);

        //    return PrepareAndLoadScript(script);
        //}

        public object ExecuteLua<T, K>(byte[] hash, T[] keys = null, K[] values = null)
        {
            var db = muxer.GetDatabase();

            //var result = db.ScriptEvaluate(hash, new RedisKey[] { (RedisKey)keys[0].ToString() }, new RedisValue[] { (RedisValue)values[0].ToString() });

            var result = db.ScriptEvaluate(hash,
                                keys.Select(s => (RedisKey)s.ToString()).ToArray(),
                                values.Select(s => (RedisValue)s.ToString()).ToArray());

            return result;
        }

        #endregion

        #region IDisposable Support
        private bool disposedValue = false; // To detect redundant calls

        protected virtual void Dispose(bool disposing)
        {
            if (!disposedValue)
            {
                if (disposing)
                {
                    muxer.Close();
                }

                // TODO: free unmanaged resources (unmanaged objects) and override a finalizer below.
                // TODO: set large fields to null.

                disposedValue = true;
            }
        }

        // This code added to correctly implement the disposable pattern.
        public void Dispose()
        {
            // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
            Dispose(true);
            // TODO: uncomment the following line if the finalizer is overridden above.
            // GC.SuppressFinalize(this);
        }


        #endregion
    }
}
