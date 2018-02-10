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

namespace HIPAA.Platform.Core.Helper
{
    using System;
    using System.Configuration;
    using Microsoft.IdentityModel.Clients.ActiveDirectory;
    using Microsoft.SqlServer.Management.AlwaysEncrypted.AzureKeyVaultProvider;
    using System.Collections.Generic;
    using System.Data.SqlClient;
    using System.Threading.Tasks;

    public class SqlEncryptionHelper
    {
        /// <summary>client credentials</summary>
        private static ClientCredential clientCredential;

        /// <summary>
        /// static initialization for column encryption azure key vault store provider otherwise
        /// calling InitializeAzureKeyVaultProvider multiple times cause key store exception
        /// </summary>
        static SqlEncryptionHelper()
        {
            InitializeAzureKeyVaultProvider(ConfigurationManager.AppSettings[CoreConstants.ClientId], 
                ConfigurationManager.AppSettings[CoreConstants.ClientSecret]);
        }

        /// <summary>
        /// registers the azure key vault store provider for column encryption
        /// using SqlColumnEncryptionAzureKeyVaultProvider
        /// </summary>
        /// <param name="clientId">Client Id</param>
        /// <param name="clientSecret">Client Secret</param>
        private static void InitializeAzureKeyVaultProvider(string clientId,string clientSecret)
        {
            clientCredential = new ClientCredential(clientId, clientSecret);

            SqlColumnEncryptionAzureKeyVaultProvider azureKeyVaultProvider =
              new SqlColumnEncryptionAzureKeyVaultProvider(GetToken);

            Dictionary<string, SqlColumnEncryptionKeyStoreProvider> providers =
              new Dictionary<string, SqlColumnEncryptionKeyStoreProvider>
              {
                  { SqlColumnEncryptionAzureKeyVaultProvider.ProviderName, azureKeyVaultProvider }
              };

            SqlConnection.RegisterColumnEncryptionKeyStoreProviders(providers);
        }

        /// <summary>
        /// token callback function
        /// </summary>
        /// <param name="authority">authority</param>
        /// <param name="resource">resource</param>
        /// <param name="scope">scope</param>
        /// <returns>token</returns>
        public async static Task<string> GetToken(string authority, string resource, string scope)
        {
            var authContext = new AuthenticationContext(authority);
            AuthenticationResult result = await authContext.AcquireTokenAsync(resource, clientCredential);

            if (result == null)
            {
                throw new InvalidOperationException("Failed to obtain the access token");
            }

            return result.AccessToken;
        }

        /// <summary>
        /// builds the connection string and sets the column encryption enabled
        /// </summary>
        /// <param name="patientSqlConnectionStr">connection string</param>
        /// <returns>CE enabled connection string</returns>
        public static string BuildPatientDbConnection(string patientSqlConnectionStr)
        {
            SqlConnectionStringBuilder patientDbConnectionBuilder =
                new SqlConnectionStringBuilder(patientSqlConnectionStr);

            patientDbConnectionBuilder.ColumnEncryptionSetting =
                SqlConnectionColumnEncryptionSetting.Enabled;

            return patientDbConnectionBuilder.ConnectionString;
        }
    }
}
