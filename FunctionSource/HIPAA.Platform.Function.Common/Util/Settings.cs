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

namespace HIPAA.Platform.Function.Common
{
    using System;
    using System.Configuration;
    using System.Threading.Tasks;
    using Microsoft.IdentityModel.Clients.ActiveDirectory;
    using Microsoft.Azure.KeyVault;

    public static class Settings
    {
        /// <summary>
        /// Get secrets from key vault using client id and secret
        /// </summary>
        /// <returns>resources</returns>
        public static async Task<(string PatientDbConnectionString,
            string StorageAccessKey,string PatientDataTableName, string ClientId, string ClientSecret,
            string PredictLengthOfStayServiceEndpoint, string PredictLengthOfStayServiceApiKey)>
            GetAppResources()
        {
            var vaultUri = ConfigurationManager.AppSettings[CommonConstants.KeyVaultUrl];

            var keyVaultClient = new KeyVaultClient(new KeyVaultClient.AuthenticationCallback(GetAccessToken));

            var storageAccessKey = (await keyVaultClient.GetSecretAsync(vaultUri, CommonConstants.StorageAccessKey)).Value;
            var patientDataTableName= (await keyVaultClient.GetSecretAsync(vaultUri, CommonConstants.PatientDataTableName)).Value;
            var patientDbConnectionString = (await keyVaultClient.GetSecretAsync(vaultUri, CommonConstants.PatientDbConnectionKey)).Value;
            var PredictLengthOfStayServiceEndpoint =
                        (await keyVaultClient.GetSecretAsync(vaultUri, CommonConstants.PredictLengthOfStayServiceEndpoint)).Value;
            var PredictLengthOfStayServiceApiKey =
                (await keyVaultClient.GetSecretAsync(vaultUri, CommonConstants.PredictLengthOfStayServiceApiKey)).Value;

            return (patientDbConnectionString, storageAccessKey, patientDataTableName,
                ConfigurationManager.AppSettings[CommonConstants.AzureKeyVaultClientId], 
                ConfigurationManager.AppSettings[CommonConstants.AzureKeyVaultClientSecret], 
                PredictLengthOfStayServiceEndpoint, PredictLengthOfStayServiceApiKey);
        }

        public async static Task<string> GetAccessToken(string authority, string resource, string scope)
        {
            var clientCredential = new ClientCredential(ConfigurationManager.AppSettings[CommonConstants.AzureKeyVaultClientId],
                ConfigurationManager.AppSettings[CommonConstants.AzureKeyVaultClientSecret]);
            var authContext = new AuthenticationContext(authority);
            AuthenticationResult result = await authContext.AcquireTokenAsync(resource, clientCredential);

            if (result == null)
            {
                throw new InvalidOperationException("Failed to obtain the access token");
            }
            return result.AccessToken;
        }
    }
}
