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

namespace HIPAA.Platform.Core.Model
{
    using System;
    using Newtonsoft.Json;

    public class Patient
    {
        [JsonProperty("id")]
        public int Id { get; set; }
        [JsonProperty("firstName")]
        public string FirstName { get; set; }
        [JsonProperty("middleName")]
        public string MiddleName { get; set; }
        [JsonProperty("lastName")]
        public string LastName { get; set; }
        [JsonProperty("eid")]
        public int Eid { get; set; }
        [JsonProperty("vdate")]
        public DateTime Vdate { get; set; }
        [JsonProperty("rcount")]
        public string Rcount { get; set; }
        [JsonProperty("gender")]
        public string Gender { get; set; }
        [JsonProperty("dialysisrenalendstage")]
        public int Dialysisrenalendstage { get; set; }
        [JsonProperty("asthma")]
        public int Asthma { get; set; }
        [JsonProperty("irondef")]
        public int Irondef { get; set; }
        [JsonProperty("pneum")]
        public int Pneum { get; set; }
        [JsonProperty("substancedependence")]
        public int Substancedependence { get; set; }
        [JsonProperty("psychologicaldisordermajor")]
        public int Psychologicaldisordermajor { get; set; }
        [JsonProperty("depress")]
        public int Depress { get; set; }
        [JsonProperty("psychother")]
        public int Psychother { get; set; }
        [JsonProperty("fibrosisandother")]
        public int Fibrosisandother { get; set; }
        [JsonProperty("malnutrition")]
        public int Malnutrition { get; set; }
        [JsonProperty("hemo")]
        public int Hemo { get; set; }
        [JsonProperty("hematocrit")]
        public float Hematocrit { get; set; }
        [JsonProperty("neutrophils")]
        public float Neutrophils { get; set; }
        [JsonProperty("sodium")]
        public float Sodium { get; set; }
        [JsonProperty("glucose")]
        public float Glucose { get; set; }
        [JsonProperty("bloodureanitro")]
        public float Bloodureanitro { get; set; }
        [JsonProperty("creatinine")]
        public float Creatinine { get; set; }
        [JsonProperty("bmi")]
        public float Bmi { get; set; }
        [JsonProperty("pulse")]
        public int Pulse { get; set; }
        [JsonProperty("respiration")]
        public float Respiration { get; set; }
        [JsonProperty("secondarydiagnosisnonicd9")]
        public int Secondarydiagnosisnonicd9 { get; set; }
        [JsonProperty("discharged")]
        public DateTime Discharged { get; set; }
        [JsonProperty("facid")]
        public string Facid { get; set; }
        [JsonProperty("lengthofstay")]
        public int Lengthofstay { get; set; }
        [JsonProperty("predlengthofstay")]
        public int PredictedLengthOfStay { get; set; }
    }
}
