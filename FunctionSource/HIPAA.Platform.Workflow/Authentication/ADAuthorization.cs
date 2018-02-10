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

namespace HIPAA.Platform.Workflow.Authentication
{
    using System;
    using System.Configuration;
    using System.Linq;
    using System.Security.Claims;
    using System.Threading.Tasks;
    using Microsoft.Azure.ActiveDirectory.GraphClient;
    using Microsoft.IdentityModel.Clients.ActiveDirectory;
    using HIPAA.Platform.Function.Common;
    using HIPAA.Platform.Core.Exceptions;

    /// <summary>
    /// AD Authorization
    /// </summary>
    public class ADAuthorization
    {
        private ClaimsIdentity userIdentity;

        public ADAuthorization(ClaimsIdentity claimsIdentity)
        {
            this.userIdentity = claimsIdentity ?? throw new AuthorizationException(System.Net.HttpStatusCode.ExpectationFailed, "invalid or no authorization code");
        }

        /// <summary>
        /// authorizes incoming principal
        /// for given role
        /// </summary>
        /// <param name="roleName">role name</param>
        /// <returns>bool</returns>
        public async Task<bool> Authorize(string roleName)
        {
            try
            {
                this.TryGetRoleNameFromToken(out string claimRoleName);

                if (!string.IsNullOrEmpty(claimRoleName))
                {
                    return this.AuthorizeUsingRoleClaimInToken(roleName, claimRoleName);
                }
                else
                {
                    return await this.AuthorizeUsingGraphClient(roleName);
                }
            }
            catch (Exception ex)
            {
                throw new AuthorizationException(System.Net.HttpStatusCode.ExpectationFailed, ex.Message);
            }
        }

        private void TryGetRoleNameFromToken(out string claimRoleName)
        {
            claimRoleName = userIdentity.FindFirst("roles")?.Value;
        }

        private bool AuthorizeUsingRoleClaimInToken(string roleName, string claimRoleName)
        {
            return claimRoleName == roleName;
        }

        private async Task<bool> AuthorizeUsingGraphClient(string roleName)
        {
            var upnClaim = userIdentity.FindFirst(CommonConstants.UpnClaimType);
            var domain = upnClaim?.Value?.Split('@')[1];

            var serviceRoot = new Uri(new Uri(CommonConstants.GraphResourceUrl), domain);

            var graphClient = new ActiveDirectoryClient(serviceRoot, async () => await GetToken());
            var currentUser = await graphClient.Users.Where(user => user.UserPrincipalName == upnClaim.Value).ExecuteSingleAsync();
            var userFetcher = currentUser as IUserFetcher;
            var roleAssignments = await userFetcher.AppRoleAssignments.ExecuteAsync();

            var roles = roleAssignments.CurrentPage.ToList();
            return roles.Exists(role => role.PrincipalDisplayName.Contains(roleName));
        }

        private static async Task<string> GetToken()
        {
            var clientCredential = new ClientCredential(ConfigurationManager.AppSettings[CommonConstants.AzureKeyVaultClientId],
                ConfigurationManager.AppSettings[CommonConstants.AzureKeyVaultClientSecret]);

            var authContext = new AuthenticationContext($"{CommonConstants.Authority}{ConfigurationManager.AppSettings[CommonConstants.TenantName]}", false);
            AuthenticationResult result = await authContext.AcquireTokenAsync("https://graph.windows.net", clientCredential);

            if (result == null)
            {
                throw new InvalidOperationException("Failed to obtain the access token");
            }
            return result.AccessToken;
        }

        public string GetCallerName()
        {
            return userIdentity.FindFirst(CommonConstants.UpnClaimType).Value;
        }
    }
}
