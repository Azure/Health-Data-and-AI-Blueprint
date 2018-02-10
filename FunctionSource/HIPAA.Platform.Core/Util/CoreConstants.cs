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

namespace HIPAA.Platform.Core
{
    public static class CoreConstants
    {
        //sql write error
        public static string SqlWriteError = "Error writing data into SQL Database: ";

        public static string DataTableWriteError = "Error writing data into Data Table: ";

        public static string BlobUrlError = "blob url cannot be null or empty ";

        public static string PredictLengthOfStayError = "Error PredictLengthOfStayService: ";

        public static string PatientAdmissionError = "Error Patient Admission ";

        public static string PatientDischargeError = "Error Patient Discharge ";

        public static string CommandError = "Command Error";

        public static string[] PredictLengthOfStayServiceValidInputKeys = new string[] {"Rcount",
        "Gender",
        "Dialysisrenalendstage",
        "Asthma",
        "Irondef",
        "Pneum",
        "Substancedependence",
        "Psychologicaldisordermajor",
        "Depress",
        "Psychother",
        "Fibrosisandother",
        "Malnutrition",
        "Hemo",
        "Hematocrit",
        "Neutrophils",
        "Sodium",
        "Glucose",
        "Bloodureanitro",
        "Creatinine",
        "Bmi",
        "Pulse",
        "Respiration",
        "Secondarydiagnosisnonicd9",
        "Vdate",
        "Discharged",
        "Facid",
        "Lengthofstay",
        "Eid"
        };

        public static string PatientAdmitted = "patient admitted";
        public static string PatientDischarged = "patient discharged";
        public static string PatientExists = "patient exists";
        public static string PatientNotExists = "patient not exist";

        public static string ClientId = "ClientId";
        public static string ClientSecret = "ClientSecret";
    }
}
