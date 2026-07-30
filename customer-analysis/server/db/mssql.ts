import sql from 'mssql';

// Parse server address: format is "IP\INSTANCE,PORT"
const serverAddr = process.env.SQL_SERVER_ADDR || '';
const [serverPart, portPart] = serverAddr.split(',');
const [server, instance] = serverPart.split('\\');

const config: sql.config = {
  server: server,
  port: parseInt(portPart) || 1433,
  user: process.env.SQL_UID || '',
  password: process.env.SQL_PWD || '',
  database: process.env.SQL_DATABASE || '',
  options: {
    encrypt: false,
    trustServerCertificate: true,
    enableArithAbort: true,
    instanceName: instance || undefined
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000
  },
  connectionTimeout: 30000,
  requestTimeout: 30000
};

let pool: sql.ConnectionPool | null = null;

export async function getPool(): Promise<sql.ConnectionPool> {
  if (!pool) {
    pool = await sql.connect(config);
    console.log('✓ Connected to SQL Server');
  }
  return pool;
}

export async function closePool(): Promise<void> {
  if (pool) {
    await pool.close();
    pool = null;
    console.log('✓ Closed SQL Server connection');
  }
}

export { sql };
