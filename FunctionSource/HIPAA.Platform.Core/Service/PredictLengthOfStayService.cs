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

namespace HIPAA.Platform.Core.Service
{
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Text;
    using System.Threading.Tasks;
    using Newtonsoft.Json;
    using HIPAA.Platform.Core.Model;
    using HIPAA.Platform.Core.Request;
    using HIPAA.Platform.Core.Response;
    using HIPAA.Platform.Core.Helper;
    using Interfaces;

    /// <summary>
    /// Predicts the Length of Stay of Patient using ml web service
    /// </summary>
    public class PredictLengthOfStayService : IPredictLengthOfStayService
    {
        /// <summary>lengthofstay prediction ml web service endpoint</summary>
        private string patientMLServiceUrl;

        /// <summary>ml api key</summary>
        private string patientMLServiceApiKey;

        public PredictLengthOfStayService(string patientMLServiceUrl, string patientMLServiceApiKey)
        {
            this.patientMLServiceUrl = patientMLServiceUrl;
            this.patientMLServiceApiKey = patientMLServiceApiKey;
        }

        public async Task<int> PredictLengthOfStay(Patient patient)
        {
            try
            {
                var predictLengthOfStayServiceRequest = this.FormatPatientDataInputForService(patient);

                var serviceResponse = await HttpHelper.PostAsync(this.patientMLServiceUrl, this.patientMLServiceApiKey,
                    predictLengthOfStayServiceRequest);

                var predictLengthOfStayServiceResponse =
                    JsonConvert.DeserializeObject<PredictLengthOfStayServiceResponse>(serviceResponse);

                var lengthOfStay = predictLengthOfStayServiceResponse.Results.output1.value.Values[0].Last();

                return Convert.ToInt32(Math.Round(Convert.ToDouble(lengthOfStay), MidpointRounding.AwayFromZero));
            }
            catch (Exception ex)
            {
                throw new PredictLengthOfStayServiceException(ex.Message,ex.InnerException);
            }
        }

        /// <summary>
        /// format the patient object into json string for sending the
        /// request payload to ml web service
        /// </summary>
        /// <param name="patient">patient</param>
        /// <returns>json data string</returns>
        private string FormatPatientDataInputForService(Patient patient)
        {
            var patientDataKeyValues = this.FilterPatientDataKey(this.GetPatientDataKeyValues(patient));
            
            var patientDataKeys = patientDataKeyValues.Keys;
            var patientDataValues = patientDataKeyValues.Values;

            var predictLengthOfStayServiceRequest = new PredictLengthOfStayServiceRequest()
            {
                Inputs = new Inputs
                {
                    input1 = new Input1
                    {
                        ColumnNames = patientDataKeys,
                        Values = new List<ICollection<string>>
                        {
                            patientDataValues
                        }
                    }
                }
            };

            return JsonConvert.SerializeObject(predictLengthOfStayServiceRequest);
        }

        /// <summary>
        /// get the patient property and value in an dictionary
        /// </summary>
        /// <param name="patient">patient</param>
        /// <returns>property value dictionary</returns>
        private Dictionary<string, string> GetPatientDataKeyValues(Patient patient)
        {
            Dictionary<string, string> patientDataKeyValueDic = new Dictionary<string, string>();

            var patientDataProperties = patient.GetType().GetProperties();

            foreach (var patientDataProperty in patientDataProperties)
            {
                patientDataKeyValueDic.Add(patientDataProperty.Name, Convert.ToString(patientDataProperty.GetValue(patient)));
            }

            return patientDataKeyValueDic;
        }

        /// <summary>
        /// filters the data for sending the input to 
        /// ml web service
        /// </summary>
        /// <param name="patientDataKeyValueDic">data dictionary</param>
        /// <returns>filterd data</returns>
        private Dictionary<string, string> FilterPatientDataKey(Dictionary<string, string> patientDataKeyValueDic)
        {
            var validPatientDataKeyValueDic = new Dictionary<string, string>();


            foreach (var validKey in CoreConstants.PredictLengthOfStayServiceValidInputKeys)
            {
                validPatientDataKeyValueDic.Add(validKey.ToLower(), patientDataKeyValueDic[validKey]);
            }

            return validPatientDataKeyValueDic;
        }
    }
}
