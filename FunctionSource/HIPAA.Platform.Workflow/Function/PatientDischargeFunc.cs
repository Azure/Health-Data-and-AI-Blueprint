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

namespace HIPAA.Platform.Workflow.Function
{
    using System;
    using System.Net;
    using System.Security.Claims;
    using Newtonsoft.Json;
    using System.Net.Http;
    using System.Threading.Tasks;
    using Microsoft.Azure.WebJobs;
    using Microsoft.Azure.WebJobs.Host;
    using Microsoft.Azure.WebJobs.Extensions.Http;
    using HIPAA.Platform.Function.Common.Telemetry;
    using HIPAA.Platform.Core.Helper;
    using HIPAA.Platform.Core;
    using System.Collections.Generic;
    using HIPAA.Platform.Function.Common.Message;
    using HIPAA.Platform.Function.Common;
    using HIPAA.Platform.Workflow.Authentication;
    using HIPAA.Platform.Workflow.Model;
    using Microsoft.Azure.ActiveDirectory.GraphClient;

    /// <summary>
    /// Patient Discharge function discharges the patient from hospital.
    /// The function is called over the http and accepts the input in FHIR format.
    /// Function translates the input FHIR format in Patient data model and updates
    /// the patient discharge information in sql database
    /// </summary>
    public static class PatientDischargeFunc
    {
        /// <summary>
        /// Patient discharge function
        /// </summary>
        /// <param name="req">http request</param>
        /// <param name="log">function log</param>
        /// <returns>discharge response</returns>
        [FunctionName(nameof(PatientDischargeFunc))]
        public static async Task<object> Run([HttpTrigger("put")]HttpRequestMessage req, TraceWriter log)
        {
            log.Info($"{nameof(PatientDischargeFunc)} triggered on {DateTime.UtcNow}");

            using (var patientTelemetry =
                new PatientTelemetry(
                    Environment.GetEnvironmentVariable(CommonConstants.InstumentationKey, EnvironmentVariableTarget.Process),
                nameof(PatientDischargeFunc)))
            {
                try
                {
                    //authorize user
                    var userIdentity = req.GetRequestContext().Principal.Identity as ClaimsIdentity;
                    var authorization = new ADAuthorization(userIdentity);

                    patientTelemetry.Caller(authorization.GetCallerName());

                    if (false == await authorization.Authorize(CommonConstants.CareLineManagerRole))
                    {
                        patientTelemetry.Unauthorized();
                        return req.CreateResponse(HttpStatusCode.Unauthorized, new
                        {
                            result = $"Unauthorized {HttpStatusCode.Unauthorized}"
                        });
                    }

                    // Get request data
                    dynamic data = await req.Content.ReadAsAsync<object>();

                    if (data == null)
                    {
                        return req.CreateResponse(HttpStatusCode.BadRequest, new
                        {
                            result = "bad request"
                        });
                    }
                  
                    // convert the input to the corresponding objects
                    InPatient inPatient = data.patient.ToObject<InPatient>();
                    Encounter encounter = data.encounter.ToObject<Encounter>();
                    int patientEid = encounter.Id;

                    //get resources from key vault
                    var appResources = await Settings.GetAppResources();
                    new SqlEncryptionHelper();

                    patientTelemetry.DischargingPatient();

                    var hospital = new Hospital(appResources.PatientDbConnectionString);
                    var id = await hospital.DischargePatient(patientEid,encounter.Period.End);

                    if (id == -1)
                    {
                        return req.CreateResponse(HttpStatusCode.OK, new
                        {
                            error = "invalid encounter id"
                        });
                    }

                    var existingPatient = await hospital.GetPatient(id);

                    patientTelemetry.PatientDischarged();

                    patientTelemetry.Success();
                    return req.CreateResponse(HttpStatusCode.OK, new
                    {
                        encounterId = existingPatient.Eid,
                        name = $"{existingPatient.FirstName} {existingPatient.MiddleName} {existingPatient.LastName}",
                        dischargedOn = existingPatient.Discharged,
                        daysStayed = existingPatient.Lengthofstay
                    });
                }
                catch (AuthorizationException ex)
                {
                    patientTelemetry.Error(ex);

                    return req.CreateResponse(HttpStatusCode.ExpectationFailed, new
                    {
                        ex.Message
                    });
                }
                catch (Exception ex)
                {
                    patientTelemetry.Error(ex);
                    return req.CreateResponse(HttpStatusCode.InternalServerError, new
                    {
                        result = "failed"
                    });
                }
            }
        }
    }
}
