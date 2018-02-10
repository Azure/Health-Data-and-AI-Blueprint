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

namespace HIPAA.Platform.Workflow.FHIR
{ 
    using System;
    using System.Collections.Generic;
    using HIPAA.Platform.Core.Model;
    using HIPAA.Platform.Workflow.Model;

    public static class FHIRMapping
    {
        /// <summary>
        /// Maps the name of the column in the output dataset to the observation code from the FHIR for easy extraction
        /// </summary>
        private static Dictionary<string, string> observationsMap = new Dictionary<string, string>
        {
            { "hematocrit", "4544-3" },
            { "neutrophils", "770-8" },
            { "sodium", "2947-0" },
            { "glucose", "2339-0" },
            { "bloodureanitro", "6299-2" },
            { "creatinine", "2160-0" },
            { "bmi", "39156-5" },
            { "pulse", "8867-4" },
            { "respiration", "9279-1" },
            { "secondarydiagnosisnonicd9", "54554-1" }
        };

        /// <summary>
        /// Maps the name of the column in the output dataset to the condition code from the FHIR for easy extraction
        /// </summary>
        private static Dictionary<string, string> conditionsMap = new Dictionary<string, string>
        {
            { "dialysisrenalendstage", "236435004" },
            { "asthma", "195967001" },
            { "irondef", "35240004" },
            { "pneum", "233604007" },
            { "substancedependence", "361055000" },
            { "phsycholgicaldisordermajor", "81659004" },
            { "depress", "35489007" },
            { "psychother", "81659004" },
            { "fibriosisandother", "263756000" },
            { "malnutrition", "263756000" },
            { "hemo", "34093004" }
        };

        /// <summary>
        /// Does the mapping from the FHIR input to the flat output that is stored into the SQL database
        /// </summary>
        /// <param name="inPatient">InPatient object built from the FHIR JSON</param>
        /// <param name="encounter">Encoutner object built from the FHIR JSON</param>
        /// <param name="observations">List of Observation objects built from the FHIR JSON</param>
        /// <param name="conditions">List of Conditions objects built from the FHIR JSON</param>
        /// <returns>patient</returns>
        public static Patient PopulatePatientData(InPatient inPatient, Encounter encounter, List<Observation> observations, List<Condition> conditions)
        {
            Patient patient = new Patient();
            // data from the patient input
            patient.FirstName = inPatient.Name[0].Given[0];
            patient.MiddleName = inPatient.Name[0].Given[1];
            patient.LastName = inPatient.Name[0].Family;
            patient.Gender = inPatient.Gender;

            // data from the encounter input
            patient.Eid = encounter.Id;
            patient.Vdate = encounter.Period.Start;
            // special handling because the data may be missing in the input FHIR JSON
            patient.Rcount = encounter.RCount == null ? "1" : encounter.RCount;
            patient.Facid = encounter.ServiceProvider.Display;

            // data from the observations input
            patient.Hematocrit = GetObservationValue(observations, "hematocrit");
            patient.Neutrophils = GetObservationValue(observations, "neutrophils");
            patient.Sodium = GetObservationValue(observations, "sodium");
            patient.Glucose = GetObservationValue(observations, "glucose");
            patient.Bloodureanitro = GetObservationValue(observations, "bloodureanitro");
            patient.Creatinine = GetObservationValue(observations, "creatinine");
            patient.Bmi = GetObservationValue(observations, "bmi");
            patient.Pulse = (int)GetObservationValue(observations, "pulse");
            patient.Respiration = GetObservationValue(observations, "respiration");
            patient.Secondarydiagnosisnonicd9 = (int)GetObservationValue(observations, "secondarydiagnosisnonicd9");

            // data from the conditions input
            patient.Dialysisrenalendstage = GetConditionValue(conditions, "dialysisrenalendstage");
            patient.Asthma = GetConditionValue(conditions, "asthma");
            patient.Irondef = GetConditionValue(conditions, "irondef");
            patient.Pneum = GetConditionValue(conditions, "pneum");
            patient.Substancedependence = GetConditionValue(conditions, "substancedependence");
            patient.Psychologicaldisordermajor = GetConditionValue(conditions, "phsycholgicaldisordermajor");
            patient.Depress = GetConditionValue(conditions, "depress");
            patient.Psychother = GetConditionValue(conditions, "psychother");
            patient.Fibrosisandother = GetConditionValue(conditions, "fibriosisandother");
            patient.Malnutrition = GetConditionValue(conditions, "malnutrition");
            patient.Hemo = GetConditionValue(conditions, "hemo");

            return patient;
        }

        /// <summary>
        /// Returns the value for the specified observation
        /// </summary>
        /// <param name="observations">List of Observations objects from the FHIR input</param>
        /// <param name="observationName">The observation value we are looking to retrieve</param>
        /// <returns>observation value</returns>
        private static float GetObservationValue(List<Observation> observations, string observationName)
        {
            Observation tempObs = observations.Find(o => o.Code.Coding[0].Code == observationsMap[observationName]);
            return tempObs == null ? 0 : tempObs.ValueQuantity.Value;
        }

        /// <summary>
        /// Returns the value (0 for resolved; 1 otherwise) for the specified condition
        /// </summary>
        /// <param name="conditions">List of Condition objects from the FHIR input</param>
        /// <param name="conditionName">The condition value we are looking to retrieve</param>
        /// <returns>condition value</returns>
        private static int GetConditionValue(List<Condition> conditions, string conditionName)
        {
            Condition tempCond = conditions.Find(c => c.Code.Coding[0].Code == conditionsMap[conditionName]);
            int returnValue = 0;
            if (tempCond != null)
            {
                returnValue = tempCond.ClinicalStatus == "resolved" ? 0 : 1;
            }
            return returnValue;
        }

    }
}
