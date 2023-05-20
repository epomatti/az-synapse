# az-synapse

```sh
terraform -chdir="infra" init
terraform -chdir="infra" apply -auto-approve
```

Enter manually in Synapse and allow Azure Services to connect to Synapse.

Create a dedicated data loading account to use maximum performance.

Create the Login in the `Master` database:

```sql
CREATE LOGIN LoadUser WITH PASSWORD = 'This!s@StrongPW';
CREATE USER LoadUser FOR LOGIN LoadUser;
```

Create the User in the data warehousing database:

```sql
CREATE USER LoadUser FOR LOGIN LoadUser;
GRANT CONTROL ON DATABASE::[syndpdatamountain] to LoadUser;
EXEC sp_addrolemember 'staticrc20', 'LoadUser';
```

Connect to the DW database with the new user and create the objects:

```sql
CREATE MASTER KEY;

CREATE EXTERNAL DATA SOURCE NYTPublic
WITH
(
    TYPE = Hadoop,
    LOCATION = 'wasbs://2013@nytaxiblob.blob.core.windows.net/'
);

CREATE EXTERNAL FILE FORMAT uncompressedcsv
WITH (
    FORMAT_TYPE = DELIMITEDTEXT,
    FORMAT_OPTIONS ( 
        FIELD_TERMINATOR = ',',
        STRING_DELIMITER = '',
        DATE_FORMAT = '',
        USE_TYPE_DEFAULT = False
    )
);
CREATE EXTERNAL FILE FORMAT compressedcsv
WITH ( 
    FORMAT_TYPE = DELIMITEDTEXT,
    FORMAT_OPTIONS ( FIELD_TERMINATOR = '|',
        STRING_DELIMITER = '',
    DATE_FORMAT = '',
        USE_TYPE_DEFAULT = False
    ),
    DATA_COMPRESSION = 'org.apache.hadoop.io.compress.GzipCodec'
);

CREATE SCHEMA ext;
```

Now we're ready to create the tables and load the data.

1. Execute the commands in the [`nyctaxy_schema.sql`](./sql/nyctaxy_schema.sql) file to create the external tables.

2. Execute the commands in the [`nyctaxy_load.sql`](./sql/nyctaxy_load.sql) file to load the data.

To monitor the data load:

```sql
SELECT
    r.command,
    s.request_id,
    r.status,
    count(distinct input_name) as nbr_files,
    sum(s.bytes_processed)/1024/1024/1024.0 as gb_processed
FROM 
    sys.dm_pdw_exec_requests r
    INNER JOIN sys.dm_pdw_dms_external_work s
    ON r.request_id = s.request_id
WHERE
    r.[label] = 'CTAS : Load [dbo].[Date]' OR
    r.[label] = 'CTAS : Load [dbo].[Geography]' OR
    r.[label] = 'CTAS : Load [dbo].[HackneyLicense]' OR
    r.[label] = 'CTAS : Load [dbo].[Medallion]' OR
    r.[label] = 'CTAS : Load [dbo].[Time]' OR
    r.[label] = 'CTAS : Load [dbo].[Weather]' OR
    r.[label] = 'CTAS : Load [dbo].[Trip]'
GROUP BY
    r.command,
    s.request_id,
    r.status
ORDER BY
    nbr_files desc, 
    gb_processed desc;
```
