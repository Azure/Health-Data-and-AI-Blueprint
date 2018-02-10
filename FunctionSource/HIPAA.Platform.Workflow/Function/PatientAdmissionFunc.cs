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
    using System.Collections.Generic;
    using System.Net;
    using System.Net.Http;
    using System.Threading.Tasks;
    using Microsoft.Azure.WebJobs;
    using Microsoft.Azure.WebJobs.Host;
    using Microsoft.Azure.WebJobs.Extensions.Http;
    using HIPAA.Platform.Function.Common.Telemetry;
    using HIPAA.Platform.Core.Service;
    using HIPAA.Platform.Core;
    using HIPAA.Platform.Core.Helper;
    using HIPAA.Platform.Function.Common;
    using HIPAA.Platform.Workflow.Authentication;
    using HIPAA.Platform.Workflow.FHIR;
    using HIPAA.Platform.Workflow.Model;
    using System.Security.Claims;
    using Microsoft.Azure.ActiveDirectory.GraphClient;
    using Newtonsoft.Json;

    /// <summary>
    /// Patient Admission function admits the patient in hospital.
    /// The function is called over http and accepts the input in FHIR format.
    /// function translates the input FHIR format in Patient data model,
    /// calls the ml service to obtain the predicted length of stay of patient
    /// to be admitted and adds the patient entry in database along with predicted length
    /// of stay value.
    /// </summary>
    public static class PatientAdmissionFunc
    {
        /// <summary>
        /// Patient Admission Functions
        /// </summary>
        /// <param name="req">http request</param>
        /// <param name="log">function log</param>
        /// <returns>admission response</returns>
        [FunctionName(nameof(PatientAdmissionFunc))]
        public static async Task<object> Run([HttpTrigger("post")]HttpRequestMessage req, TraceWriter log)
        {
            log.Info($"{nameof(PatientAdmissionFunc)} triggered on {DateTime.UtcNow}");

            using (var patientTelemetry =
                 new PatientTelemetry(Environment.GetEnvironmentVariable(CommonConstants.InstumentationKey,
                 EnvironmentVariableTarget.Process),
                 nameof(PatientAdmissionFunc)))
            {
                try
                {
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
                    List<Observation> observations = data.observations.ToObject<List<Observation>>();
                    List<Condition> conditions = data.conditions.ToObject<List<Condition>>();

                    //get resource from key vault
                    var appResources = await Settings.GetAppResources();

                    new SqlEncryptionHelper();

                    //get patient data from FHIR data
                    var patient = FHIRMapping.PopulatePatientData(inPatient, encounter, observations, conditions);

                    try
                    {
                        var predictLengthOfStayService =
                            new PredictLengthOfStayService(appResources.PredictLengthOfStayServiceEndpoint,
                            appResources.PredictLengthOfStayServiceApiKey);

                        patientTelemetry.DependencyStarted();
                        patient.PredictedLengthOfStay = await predictLengthOfStayService.PredictLengthOfStay(patient);                     
                        patientTelemetry.DependencyCompleted(nameof(PredictLengthOfStayService),
                           "PredictLengthOfStay", true);
                    }
                    catch (PredictLengthOfStayServiceException ex)
                    {
                        patientTelemetry.DependencyCompleted(nameof(PredictLengthOfStayService),
                           "PredictLengthOfStay", false);
                        patientTelemetry.Error(ex);
                    }

                    var hospital = new Hospital(appResources.PatientDbConnectionString);
                    var id = await hospital.AdmitPatient(patient);

                    if (id == -1)
                    {
                        return req.CreateResponse(HttpStatusCode.OK, new
                        {
                            result = "invalid encounter id"
                        });
                    }

                    var existingPatient = await hospital.GetPatient(id);

                    patientTelemetry.Success();
                    return req.CreateResponse(HttpStatusCode.OK, new
                    {
                        encounterId = existingPatient.Eid,
                        name = $"{existingPatient.FirstName} {existingPatient.MiddleName} {existingPatient.LastName}",
                        gender = existingPatient.Gender,
                        admittedOn = existingPatient.Vdate
                    });
                }
                catch (AuthorizationException ex)
                {
                    patientTelemetry.Error(ex);

                    return req.CreateResponse(HttpStatusCode.ExpectationFailed, new
                    {
                        error = ex.Message
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
