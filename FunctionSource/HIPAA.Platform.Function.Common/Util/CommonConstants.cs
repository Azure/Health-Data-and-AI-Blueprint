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
    public static class CommonConstants
    {
        //telmetry keys
        public static string InstumentationKey = "APPINSIGHTS_INSTRUMENTATIONKEY";

        public static string StorageAccessKey = "StorageAcc-PatientAccesskey";

        public static string PatientDbConnectionKey = "Sqldb-ConnectionString";

        public static string PatientDataTableName = "Sqldb-PatientDataTableName";

        public static string AzureKeyVaultClientId = "ClientId";

        public static string AzureKeyVaultClientSecret = "ClientSecret";

        public static string PredictLengthOfStayServiceEndpoint = "ML-PredictLengthOfStayServiceEndPoint";

        public static string PredictLengthOfStayServiceApiKey = "ML-PredictLengthOfStayApiKey";

        public static string KeyVaultUrl = "VaultUrl";

        public static string CareLineManagerRole = "CareLineManager";

        public static string GraphResourceUrl = "https://graph.windows.net";

        public static string UpnClaimType = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn";

        public static string Authority = "https://login.microsoftonline.com/";

        public static string FunctionAppClientId = "AppClientId";

        public static string FunctionappClientSecret = "AppClientSecret";

        public static string TenantName = "TenantName";

        public static string SubscriptionValidationEvent = "Microsoft.EventGrid.SubscriptionValidationEvent";
    }
}
