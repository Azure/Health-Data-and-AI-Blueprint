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
    /// <summary>
    /// patient schema constants
    /// </summary>
    public static class PatientSchema
    {
        //procedures
        public static string PatientAdmissionProcedure = "[dbo].[AdmitPatient]";
        public static string PatientDischargeProcedure = "[dbo].[DischargePatient]";

        //parameters
        public static string FirstParameterName ="@FirstName";
        public static string MiddleParameterName = "@MiddleName";
        public static string LastParameterName = "@LastName";
        public static string EidParameterName = "@Eid";
        public static string VdateParameterName = "@Vdate";
        public static string RcountParameterName = "@Rcount";
        public static string GenderParameterName = "@Gender";
        public static string DialysisRenalEndstageParameterName = "@DialysisRenalEndStage";
        public static string asthmaParameterName = "@Asthma";
        public static string irondefParameterName = "@IronDef";
        public static string pneumParameterName = "@Pneum";
        public static string substancedependenceParameterName = "@SubstanceDependence";
        public static string psychologicaldisordermajorParameterName = "@PsychologicalDisorderMajor";
        public static string depressParameterName = "@Depress";
        public static string psychotherParameterName = "@Psychother";
        public static string fibrosisandotherParameterName = "@FibrosisAndOther";
        public static string malnutritionParameterName = "@Malnutrition";
        public static string hemoParameterName = "@Hemo";
        public static string hematocritParameterName = "@Hematocrit";
        public static string neutrophilsParameterName = "@Neutrophils";
        public static string sodiumParameterName = "@Sodium";
        public static string glucoseParameterName = "@Glucose";
        public static string bloodureanitroParameterName = "@BloodUreaNitro";
        public static string creatinineParameterName = "@Creatinine";
        public static string bmiParameterName = "@Bmi";
        public static string pulseParameterName = "@Pulse";
        public static string respirationParameterName = "@Respiration";
        public static string secondarydiagnosisnonicd9ParameterName = "@SecondaryDiagnosisNonIcd9";
        public static string dischargedParameterName = "@Discharged";
        public static string facidParameterName = "@Facid";
        public static string lengthofstayParameterName = "@LengthOfStay";
        public static string predictedLengthOfStayParameterName = "@PredLengthOfStay";
        public static string resultParameterName = "@result";

        public static string dischargeDateParameterName = "@DischargeDate";

        //result
        public static string OperationSuccessResult = "0";
        public static string OperationFailureResult = "-1";
        public static int PatientExistsResult = -1;
    }
}
