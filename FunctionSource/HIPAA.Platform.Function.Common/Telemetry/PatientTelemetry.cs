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

namespace HIPAA.Platform.Function.Common.Telemetry
{
    using System;
    using System.Diagnostics;
    using Microsoft.ApplicationInsights;
    using Microsoft.ApplicationInsights.Extensibility;
    using Microsoft.ApplicationInsights.DataContracts;
    using System.Collections.Generic;

    /// <summary>
    /// PatientTelemetry tracks the custom events, exceptions and metrics
    /// using TelemetryClient 
    /// </summary>
    public class PatientTelemetry : IDisposable
    {
        /// <summary>instrumentation key</summary>
        private string patientTelemetryKey;

        /// <summary>target function name</summary>
        private string target;

        /// <summary>telemetry request</summary>
        private RequestTelemetry patientTelemetryRequest = new RequestTelemetry();

        /// <summary>telemetry client</summary>
        private TelemetryClient patientTelemetryclient;

        /// <summary>request stopwatch</summary>
        private Stopwatch requestStopwatch = new Stopwatch();

        /// <summary>dependency stopwatch</summary>
        private Stopwatch dependencyStopwatch = new Stopwatch();

        /// <summary>
        /// PatientTelemetry tracks the custom events, exceptions and metrics
        /// using TelemetryClient
        /// </summary>
        /// <param name="patientTelemetryKey">instrumentation key</param>
        /// <param name="target">target function</param>
        public PatientTelemetry(string patientTelemetryKey, string target)
        {
            this.patientTelemetryKey = TelemetryConfiguration.Active.InstrumentationKey = patientTelemetryKey;
            this.patientTelemetryclient = new TelemetryClient() { InstrumentationKey = this.patientTelemetryKey };
            this.target = target;

            this.Initialize();
            this.TargetInvoked();           
        }

        /// <summary>
        /// initialize telemetry context opeation is and name
        /// start the request stopwatch
        /// </summary>
        private void Initialize()
        {
            this.patientTelemetryRequest.GenerateOperationId();
            this.patientTelemetryclient.Context.Operation.Id = this.patientTelemetryRequest.Id;
            this.patientTelemetryclient.Context.Operation.Name = this.target;
            
            this.requestStopwatch.Start();
        }

        /// <summary>
        /// incoming request data
        /// </summary>
        /// <param name="requestData">request data</param>
        public void Request(string requestData)
        {
            this.patientTelemetryclient.TrackEvent($"Request Recieved : {requestData}");
        }

        public void Caller(string callerName)
        {
            this.patientTelemetryRequest.Context.User.AuthenticatedUserId = callerName;
            this.patientTelemetryRequest.Context.User.Id = callerName;
        }
        /// <summary>
        /// ingestion started
        /// </summary>
        public void IngestionStarted()
        {
            this.patientTelemetryclient.TrackEvent($"Ingestion Started on {DateTime.UtcNow}");
        }

        /// <summary>
        /// ingestion completed
        /// </summary>
        public void IngestionCompleted()
        {
            this.patientTelemetryclient.TrackEvent($"Ingestion Completed on {DateTime.UtcNow}");
            this.Success();
        }

        public void AdmittingPatient()
        {
            this.patientTelemetryclient.TrackEvent($"Admitting patient on {DateTime.UtcNow}");
        }

        public void PatientAdmitted()
        {
            this.patientTelemetryclient.TrackEvent($"Patient admitted on {DateTime.UtcNow}");
            this.Success();
        }

        public void PredictingLengthOfStay()
        {
            this.patientTelemetryclient.TrackEvent($"Predicting Length of Stay on {DateTime.UtcNow}");
        }

        public void PredictedLengthOfStay()
        {
            this.patientTelemetryclient.TrackEvent($"Predicted Length of Stay on {DateTime.UtcNow}");
        }

        public void DependencyStarted()
        {
            this.dependencyStopwatch.Start();
        }

        public void DependencyCompleted(string dependencyName,string commandName,bool success)
        {
            this.patientTelemetryclient.TrackDependency(dependencyName, commandName,
                DateTime.UtcNow - this.dependencyStopwatch.Elapsed, this.dependencyStopwatch.Elapsed, success);

            this.dependencyStopwatch.Stop();
        }

        public void DischargingPatient()
        {
            this.patientTelemetryclient.TrackEvent($"Discharging patient on {DateTime.UtcNow}");
        }

        public void PatientDischarged()
        {
            this.patientTelemetryclient.TrackEvent($"Patient discharged on {DateTime.UtcNow}");
            this.Success();
        }

        public void Error(Exception ex)
        {
            this.patientTelemetryclient.TrackException(ex);
            this.Failure();
        }

        public void Unauthorized()
        {
            this.TrackRequest(DateTime.UtcNow - this.requestStopwatch.Elapsed,
               this.requestStopwatch.Elapsed, "401", false);
        }

        /// <summary>
        /// track patieent telemetry request
        /// </summary>
        /// <param name="startTime">start time</param>
        /// <param name="duration">duration</param>
        /// <param name="responseCode">response</param>
        /// <param name="success">success</param>
        public void TrackRequest(DateTime startTime,TimeSpan duration,string responseCode,bool success)
        {
            this.patientTelemetryRequest.Name = this.target;
            this.patientTelemetryRequest.Timestamp = startTime;
            this.patientTelemetryRequest.Duration = duration;
            this.patientTelemetryRequest.Success = success;
            this.patientTelemetryRequest.ResponseCode = responseCode;

            this.patientTelemetryclient.TrackRequest(this.patientTelemetryRequest);
        }

        /// <summary>
        /// operation metrics
        /// </summary>
        /// <param name="metricsProperties">metric properties</param>
        public void Metrics(IDictionary<string, double> metricsProperties)
        {
            this.patientTelemetryclient.TrackEvent("Ingestion Metrics", null, metricsProperties);

            foreach(var metric in metricsProperties)
            {
                this.patientTelemetryclient.TrackMetric(metric.Key, metric.Value);
                this.patientTelemetryRequest.Metrics.Add(metric.Key, metric.Value);
            }
        }

        /// <summary>
        /// target invoked
        /// </summary>
        private void TargetInvoked()
        {
            this.patientTelemetryclient.TrackEvent($"Target {target} Invoked on {DateTime.UtcNow}");
        }

        /// <summary>
        /// target completed
        /// </summary>
        private void TargetCompleted()
        {
            this.patientTelemetryclient.TrackEvent($"Target {target} Completed on {DateTime.UtcNow}");
        }

        /// <summary>
        /// request succedded
        /// </summary>
        public void Success()
        {
            this.TrackRequest(DateTime.UtcNow - this.requestStopwatch.Elapsed,
                this.requestStopwatch.Elapsed, "200", true);
        }

        /// <summary>
        /// request failed
        /// </summary>
        public void Failure()
        {
            this.TrackRequest(DateTime.UtcNow - this.requestStopwatch.Elapsed,
               this.requestStopwatch.Elapsed, "500", false);
        }

        /// <summary>
        /// request unsupported
        /// </summary>
        public void Unsupported()
        {
            this.patientTelemetryclient.TrackRequest(this.target, DateTime.UtcNow - this.requestStopwatch.Elapsed,
               this.requestStopwatch.Elapsed, "501", true);
        }

        /// <summary>
        /// stop stopwatch and fire target completed event
        /// </summary>
        public void Dispose()
        {
            this.requestStopwatch.Stop();
            this.TargetCompleted();
        }
    }
}
