// Copyright (c) Microsoft Open Technologies, Inc. All rights reserved. See License.txt in the project root for license information.

namespace System.Data.Entity.Migrations
{
    using System.Data.Common;
    using System.Data.Entity.Migrations.Sql;
    using System.Data.Entity.SqlServer;
    // using System.Data.Entity.SqlServerCompact; // SqlServerCompact not in this fork
    using System.Data.Entity.TestHelpers;
    using System.Data.Entity.Utilities;
    using System.Data.SqlClient;
    // using System.Data.SqlServerCe; // SqlServerCompact not in this fork
    using System.IO;

    public abstract class TestDatabase
    {
        public string ConnectionString { get; set; }
        public string ProviderName { get; protected set; }
        public string ProviderManifestToken { get; protected set; }
        public MigrationSqlGenerator SqlGenerator { get; protected set; }
        public virtual InfoContext Info { get; protected set; }

        public abstract bool Exists();

        public abstract void EnsureDatabase();

        public abstract void ResetDatabase();

        public abstract void DropDatabase();

        public abstract DbConnection CreateConnection(string connectionString);

        protected static InfoContext CreateInfoContext(DbConnection connection, bool supportsSchema = true)
        {
            var info = new InfoContext(connection, true, supportsSchema);
            info.Database.Initialize(force: false);

            return info;
        }

        public void ExecuteNonQuery(string commandText, string connectionString = null)
        {
            Execute(commandText, c => c.ExecuteNonQuery(), connectionString);
        }

        protected T ExecuteScalar<T>(string commandText, string connectionString = null)
        {
            return Execute(commandText, c => (T)c.ExecuteScalar(), connectionString);
        }

        private T Execute<T>(string commandText, Func<DbCommand, T> action, string connectionString = null)
        {
            connectionString = connectionString ?? ConnectionString;

            using (var connection = CreateConnection(connectionString))
            {
                using (var command = connection.CreateCommand())
                {
                    connection.Open();
                    command.CommandText = commandText;

                    return action(command);
                }
            }
        }
    }

    public class SqlTestDatabase : TestDatabase
    {
        private readonly string _name;

        public SqlTestDatabase(string name)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                throw new ArgumentException("'" + name + "' can not be null or empty.");
            }

            _name = name;

            ConnectionString = ModelHelpers.SimpleConnectionString(name);
            ProviderName = SqlProviderServices.ProviderInvariantName;
            ProviderManifestToken = "2008";
            SqlGenerator = new SqlServerMigrationSqlGenerator();
            Info = CreateInfoContext(new SqlConnection(ConnectionString));
        }

        public override void EnsureDatabase()
        {
            var databaseExistsSql = "SELECT Count(*) FROM sys.databases WHERE name = N'" + _name + "'";
            var databaseExists = ExecuteScalar<int>(databaseExistsSql, ModelHelpers.SimpleConnectionString("master")) == 1;
            if (!databaseExists)
            {
                var createDatabaseSql = "CREATE DATABASE [" + _name + "]";
                ExecuteNonQuery(createDatabaseSql, ModelHelpers.SimpleConnectionString("master"));
            }

            ResetDatabase();
        }

        public override void ResetDatabase()
        {
            ExecuteNonQuery(
                @"DECLARE @sql NVARCHAR(1024);

                  DECLARE @constraint_name NVARCHAR(256),
                          @table_schema NVARCHAR(100),
                          @table_name NVARCHAR(100);
                 
                  DECLARE constraint_cursor CURSOR FOR
                  SELECT constraint_name, table_schema, table_name
                  FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS 
                  WHERE constraint_catalog = 'MigrationsTest'
                  AND constraint_type = 'FOREIGN KEY'
                 
                  OPEN constraint_cursor;
                  FETCH NEXT FROM constraint_cursor INTO @constraint_name, @table_schema, @table_name;
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                      SELECT @sql = 'ALTER TABLE [' + REPLACE(@table_schema, ']', ']]') + '].[' + REPLACE(@table_name, ']', ']]') + '] 
                                     DROP CONSTRAINT [' + REPLACE(@constraint_name, ']', ']]') + ']';
                      EXEC sp_executesql @sql; 
                      FETCH NEXT FROM constraint_cursor INTO @constraint_name, @table_schema, @table_name;
                  END
                  CLOSE constraint_cursor;
                  DEALLOCATE constraint_cursor;

                  DECLARE table_cursor CURSOR FOR
                  SELECT 'DROP TABLE [' + REPLACE(SCHEMA_NAME(schema_id), ']', ']]') + '].[' + REPLACE(object_name(object_id), ']', ']]') + '];'
                  FROM sys.objects
                  WHERE TYPE = 'U'
                  
                  OPEN table_cursor;
                  FETCH NEXT FROM table_cursor INTO @sql;
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                      EXEC sp_executesql @sql;
                      FETCH NEXT FROM table_cursor INTO @sql;
                  END
                  CLOSE table_cursor;
                  DEALLOCATE table_cursor;

                  DECLARE sproc_cursor CURSOR FOR
                  SELECT 'DROP PROCEDURE [' + REPLACE(SCHEMA_NAME(schema_id), ']', ']]') + '].[' + REPLACE(object_name(object_id), ']', ']]') + '];'
                  FROM sys.objects
                  WHERE TYPE = 'P'
                  
                  OPEN sproc_cursor;
                  FETCH NEXT FROM sproc_cursor INTO @sql;
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                      EXEC sp_executesql @sql;
                      FETCH NEXT FROM sproc_cursor INTO @sql;
                  END
                  CLOSE sproc_cursor;
                  DEALLOCATE sproc_cursor;");
        }

        public override void DropDatabase()
        {
            SqlConnection.ClearAllPools();
            if (DatabaseTestHelpers.IsSqlAzure(ConnectionString))
            {
                string azureConnectionString = ConnectionString + ";Database=Master;";
                ExecuteNonQuery(
                @"DROP DATABASE [" + _name + "]", azureConnectionString);
            }
            else
            {
                ExecuteNonQuery(
                @"ALTER DATABASE [" + _name
                + "] SET OFFLINE WITH ROLLBACK IMMEDIATE;ALTER DATABASE [" + _name
                + "] SET ONLINE;DROP DATABASE [" + _name + "]");   
            }                       
        }

        public override bool Exists()
        {
            return Database.Exists(ConnectionString);
        }

        public override DbConnection CreateConnection(string connectionString)
        {
            return new SqlConnection(connectionString);
        }
    }

    // SqlCeTestDatabase removed — SqlServerCompact provider not included in this fork.
}
