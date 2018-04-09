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

namespace HIPAA.Platform.Workflow
{
    using System;
    using System.Linq;
    using System.Net;
    using Newtonsoft.Json;
    using System.Net.Http;
    using System.Threading.Tasks;
    using Microsoft.Azure.WebJobs;
    using Microsoft.Azure.WebJobs.Host;
    using HIPAA.Platform.Function.Common.Telemetry;
    using HIPAA.Platform.Core;
    using HIPAA.Platform.Function.Common.Message;
    using System.Collections.Generic;
    using HIPAA.Platform.Function.Common;
    using HIPAA.Platform.Core.Helper;
    using Microsoft.Azure.EventGrid.Models;
    using Newtonsoft.Json.Linq;

    /// <summary>
    /// PatientDataBulkImportFun is triggered on blob storage event,
    /// stores the data from storage blob to SQL Database
    /// </summary>
    public static class PatientDataBulkImportFunc
    {
        [FunctionName(nameof(PatientDataBulkImportFunc))]
        public static async Task<object> Run([HttpTrigger(WebHookType = "genericJson")]HttpRequestMessage req, TraceWriter log)
        {
            log.Info($"{nameof(PatientDataBulkImportFunc)} triggered on {DateTime.UtcNow}");

            using (var patientTelemetry = new PatientTelemetry(
                Environment.GetEnvironmentVariable(CommonConstants.InstumentationKey, EnvironmentVariableTarget.Process),
                nameof(PatientDataBulkImportFunc)))
            {
                try
                {
                    string jsonContent = await req.Content.ReadAsStringAsync();

                    EventGridEvent[] message = JsonConvert.DeserializeObject<EventGridEvent[]>(jsonContent);


                    patientTelemetry.Request(nameof(PatientDataBulkImportFunc));


                    // If the request is for subscription validation, send back the validation code.

                    if (string.Equals((string)message[0].EventType, CommonConstants.SubscriptionValidationEvent,
                        StringComparison.OrdinalIgnoreCase))
                    {
                        JObject dataObject = message[0].Data as JObject;
                        var eventData = dataObject.ToObject<SubscriptionValidationEventData>();
                        var responseData = new SubscriptionValidationResponseData();
                        responseData.ValidationResponse = eventData.ValidationCode;
                        return req.CreateResponse(HttpStatusCode.OK, responseData);

                    }
                
                    //filter event type
                    if (message[0].EventType != Events.BlobCreatedEvent)
                    {
                        patientTelemetry.Unsupported();

                        return req.CreateResponse(HttpStatusCode.OK, new
                        {
                            result = $"cannot process event {message[0].EventType}"
                        });
                    }

                    JObject blobObject = message[0].Data as JObject;

                    //get resouces from key vault
                    var appResources = await Settings.GetAppResources();
                    var storageEvent = blobObject.ToObject<BlobData>();
                    string patientDataBlobUrl = storageEvent.url;
                    new SqlEncryptionHelper();

                    patientTelemetry.IngestionStarted();

                    var patientDataIngestion = new PatientDataIngestion(appResources.StorageAccessKey,
                        appResources.PatientDbConnectionString, appResources.PatientDataTableName);

                    var totalRowsProcessed = await patientDataIngestion.Process(patientDataBlobUrl);
                    var totalRecordsStored = await patientDataIngestion.GetTotalPatientRecordsStored();

                    patientTelemetry.IngestionCompleted();

                    patientTelemetry.Metrics(
                        new Dictionary<string, double> { { Metrics.RowsProcessed, totalRowsProcessed },
                            { Metrics.RowsStored, totalRecordsStored }
                        });

                    patientTelemetry.Success();
                    return req.CreateResponse(HttpStatusCode.OK, new
                    {
                        result = "success"
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
