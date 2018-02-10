//*****************************************************************************************************
// Copyright (c) Microsoft Corporation and Avyan Consulting Corp. All rights reserved.

// Permission is hereby granted, free of charge, to any person 
// obtaining a copy of this software and associated documentation 
// files (the "Software"), to deal in the Software without restriction, 
// including without limitation the rights to use, copy, modify, merge, 
// publish, distribute, sublicense, and/or sell copies of the Software, 
// and to permit persons to whom the Software is furnished to do so, 
// subject to the following conditions:
// The above copyright notice and this permission notice shall be 
// included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, 
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, 
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//******************************************************************************************************

namespace HIPAA.Platform.Core
{
    using System;
    using System.Data;
    using System.Data.SqlClient;
    using System.Threading.Tasks;
    using System.IO;
    using Microsoft.WindowsAzure.Storage.Auth;
    using Microsoft.WindowsAzure.Storage.Blob;
    using Microsoft.WindowsAzure.Storage;
    using Interfaces;

    /// <summary>
    /// PatientDataIngestion process the Patient Data 
    /// from Blob Storage into SQL Database
    /// </summary>
    public class PatientDataIngestion : IPatientDataIngestion
    {
        /// <summary>Patient SQL DB Connection string </summary>
        private string connectionString;

        /// <summary>Patient table name </summary>
        private string patientDataTableName;

        /// <summary>Patient blob storage access key</summary>
        private string patientStorageAccountKey;

        /// <summary>
        /// PatientDataIngestion process the Patient Data 
        /// from Blob Storage into SQL Database
        /// </summary>
        /// <param name="patientStorageAccountKey">storage account access key</param>
        /// <param name="connectionString">patient db connection string</param>
        /// <param name="patientDataTableName">patient table name</param>
        public PatientDataIngestion(string patientStorageAccountKey,
            string connectionString, string patientDataTableName)
        {
            this.connectionString = connectionString;
            this.patientDataTableName = patientDataTableName;
            this.patientStorageAccountKey = patientStorageAccountKey;
        }

        public async Task<int> Process(string patientDataBlobUrl)
        {
            if (string.IsNullOrEmpty(patientDataBlobUrl))
            {
                throw new ArgumentNullException(CoreConstants.BlobUrlError);
            }

            return await this.ImportDataFromBlobToSqlAsync(patientDataBlobUrl, this.connectionString);
        }

        /// <summary>
        /// Get Blob details;
        /// storage name, container name and blob name
        /// </summary>
        /// <param name="trainingDataBlobUrl">blob url</param>
        /// <returns>blob details</returns>
        public (string storageAccountName, string containerName, string blobName) GetBlobDetails(string trainingDataBlobUrl)
        {
            Uri uri = new Uri(trainingDataBlobUrl);
            string storageAccountName = uri.Host.Substring(0, uri.Host.IndexOf('.'));

            return (storageAccountName, uri.Segments[1].TrimEnd(new char[] { '/' }), uri.Segments[2]);
        }

        /// <summary>
        /// writes the data from patient data blob
        /// using blob uri into sql database
        /// </summary>
        /// <param name="patientDataBlobUri">patient data uri</param>
        /// <param name="sqlConnectionStr">patient db connection string</param>
        /// <returns>Task</returns>
        private async Task<int> ImportDataFromBlobToSqlAsync(string patientDataBlobUri, string sqlConnectionStr)
        {
            var patientDataBlob = this.GetPatientBlobFromUri(patientDataBlobUri);

            var patientDataTable = this.WriteDataIntoDataTable(patientDataBlob);

            await this.WriteDataTableToSqlDbAsync(patientDataTable, this.connectionString);

            return patientDataTable.Rows.Count;
        }

        /// <summary>
        /// Gets total number of records stored in database
        /// </summary>
        /// <returns>number of records stored</returns>
        public async Task<int> GetTotalPatientRecordsStored()
        {
            int totalRowsStored = 0;

            using (var patientDataConnection = new SqlConnection(this.connectionString))
            {
                await patientDataConnection.OpenAsync();

                SqlCommand patientRecordsCountCommand = new SqlCommand
                {
                    CommandText = $"select count(*) from {this.patientDataTableName}",
                    Connection = patientDataConnection,
                    CommandTimeout = 0
                };
                totalRowsStored = Convert.ToInt32(await patientRecordsCountCommand.ExecuteScalarAsync());
            }
            return totalRowsStored;
        }


        /// <summary>
        /// Returns the patient data blob using blob uri
        /// </summary>
        /// <param name="patientDataBlobUri">patient blob uri</param>
        /// <returns>blob</returns>
        private CloudBlob GetPatientBlobFromUri(string patientDataBlobUri)
        {
            var patientStorageDetails = this.GetBlobDetails(patientDataBlobUri);

            StorageCredentials patientStorageAccountCred =
                new StorageCredentials(patientStorageDetails.storageAccountName, this.patientStorageAccountKey);
            CloudStorageAccount patientDataStorageAccount = new CloudStorageAccount(patientStorageAccountCred, true);

            CloudBlobClient patientBlobClient =
                new CloudBlobClient(patientDataStorageAccount.BlobEndpoint, patientDataStorageAccount.Credentials);

            CloudBlobContainer patientStorageContainer =
                patientBlobClient.GetContainerReference(patientStorageDetails.containerName);

            return patientStorageContainer.GetBlobReference(patientStorageDetails.blobName);
        }


        /// <summary>
        /// Writes the data from patient blob into data table
        /// </summary>
        /// <param name="patientDataBlob">patient blob</param>
        /// <returns>data table with data</returns>
        private DataTable WriteDataIntoDataTable(CloudBlob patientDataBlob)
        {
            var patientDataTable = new DataTable();

            try
            {
                using (var patientDataStream = patientDataBlob.OpenRead())
                {
                    using (var patientStreamReader = new StreamReader(patientDataStream))
                    {
                        this.WriteHeaderIntoDataColumns(patientStreamReader.ReadLine(), patientDataTable);

                        while (!patientStreamReader.EndOfStream)
                        {
                            this.WriteDataIntoDataTable(patientStreamReader.ReadLine(), patientDataTable);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                throw new Exception(CoreConstants.DataTableWriteError, ex);
            }

            return patientDataTable;
        }

        /// <summary>
        /// writes the header into patient data table columns
        /// </summary>
        /// <param name="patientDataHeaderLine">header</param>
        /// <param name="patientDataTable">data table</param>
        private void WriteHeaderIntoDataColumns(string patientDataHeaderLine, DataTable patientDataTable)
        {
            var patientDataHeader = patientDataHeaderLine.Split(',');

            foreach (var header in patientDataHeader)
            {
                patientDataTable.Columns.Add(header);
            }
        }

        /// <summary>
        /// writes the patient data into data table
        /// </summary>
        /// <param name="patientDataRowLine">patient data</param>
        /// <param name="patientDataTable">data table</param>
        private void WriteDataIntoDataTable(string patientDataRowLine, DataTable patientDataTable)
        {
            var patientDataRow = patientDataRowLine.Split(',');

            var row = patientDataTable.NewRow();
            row.ItemArray = patientDataRow;
            patientDataTable.Rows.Add(row);
        }

        /// <summary>
        /// writes the data from data table into patient sql db
        /// using sqlbulkcopy
        /// </summary>
        /// <param name="patientDataTable">patient data table</param>
        /// <param name="patientSqlConnectionStr">patient sql connection string</param>
        /// <returns>Task</returns>
        private async Task WriteDataTableToSqlDbAsync(DataTable patientDataTable, string patientSqlConnectionStr)
        {
            patientSqlConnectionStr = this.BuildPatientDbConnection(patientSqlConnectionStr);

            SqlConnection patientDb = new SqlConnection(patientSqlConnectionStr);

            try
            {
                SqlBulkCopy patientDataBulkCopy = new SqlBulkCopy(patientDb.ConnectionString, SqlBulkCopyOptions.TableLock)
                {
                    DestinationTableName = this.patientDataTableName,
                    BatchSize = patientDataTable.Rows.Count,
                    BulkCopyTimeout = 0
                };

                await patientDb.OpenAsync();
                await patientDataBulkCopy.WriteToServerAsync(patientDataTable);

                patientDataBulkCopy.Close();
                patientDb.Close();
            }
            catch (Exception ex)
            {
                throw new Exception($"{CoreConstants.SqlWriteError}{ex.Message}", ex);
            }
        }


        /// <summary>
        /// build patient db conneection string
        /// set column encryption setting enabled
        /// </summary>
        /// <param name="patientSqlConnectionStr">patient db connection string</param>
        /// <returns>modified connection string</returns>
        private string BuildPatientDbConnection(string patientSqlConnectionStr)
        {
            SqlConnectionStringBuilder patientDbConnectionBuilder =
                new SqlConnectionStringBuilder(patientSqlConnectionStr)
                {
                    ColumnEncryptionSetting =
                SqlConnectionColumnEncryptionSetting.Enabled
                };

            return patientDbConnectionBuilder.ConnectionString;
        }
    }
}
