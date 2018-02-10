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
    using System;
    using System.Threading.Tasks;
    using HIPAA.Platform.Core.Model;
    using Interfaces;
    using System.Data.SqlClient;
    using System.Data;
    using HIPAA.Platform.Core.Helper;
    using System.Collections.Generic;
    using HIPAA.Platform.Core.Exceptions;

    /// <summary>
    /// Hospital implements the properties
    /// defined by IHospital interface
    /// </summary>
    public class Hospital : IHospital
    {
        /// <summary>
        /// patient DB connection string
        /// </summary>
        private string patientDbConnectionStr;

        /// <summary>
        /// create the hospital instance with
        /// patient data connection string
        /// </summary>
        /// <param name="patientDbConnectionStr">patient db connection string</param>
        public Hospital(string patientDbConnectionStr)
        {
            this.patientDbConnectionStr = patientDbConnectionStr;
        }

        public async Task<int> AdmitPatient(Patient patient)
        {
            Guard.NullCheckAndThrow(patient);

            var commandResult = 0;

            using (var patientConnection =
                new SqlConnection(SqlEncryptionHelper.BuildPatientDbConnection(this.patientDbConnectionStr)))
            {
                await patientConnection.OpenAsync();

                try
                {
                    var patientAdmissionCommand = new SqlCommand
                    {
                        Connection = patientConnection,
                        CommandText = PatientSchema.PatientAdmissionProcedure,
                        CommandType = CommandType.StoredProcedure
                    };

                    var admitPatientParam = this.CreateAdmitPatientParam(patient);
                    patientAdmissionCommand.Parameters.AddRange(admitPatientParam);
                    patientAdmissionCommand.Parameters[PatientSchema.resultParameterName].Direction = 
                        ParameterDirection.Output;

                    await patientAdmissionCommand.ExecuteNonQueryAsync();
                    commandResult = Convert.ToInt32(patientAdmissionCommand.Parameters[PatientSchema.resultParameterName].Value);
                }
                catch (Exception ex)
                {
                    throw new Exception($"{CoreConstants.PatientAdmissionError}{ex.Message}", ex);
                }

                return commandResult;
            }
        }

        public async Task<int> DischargePatient(int eid,DateTime dischargeDate)
        {
            Guard.CheckValidEid(eid);

            int commandResult = 0;

            using (var patientConnection =
                new SqlConnection(SqlEncryptionHelper.BuildPatientDbConnection(this.patientDbConnectionStr)))
            {
                await patientConnection.OpenAsync();

                try
                {
                    var patientDischargeCommand = new SqlCommand
                    {
                        Connection = patientConnection,
                        CommandText = PatientSchema.PatientDischargeProcedure,
                        CommandType = CommandType.StoredProcedure
                    };

                    patientDischargeCommand.Parameters.Add(new SqlParameter(PatientSchema.EidParameterName, eid));
                    patientDischargeCommand.Parameters.Add(new SqlParameter(PatientSchema.dischargeDateParameterName, dischargeDate));
                    patientDischargeCommand.Parameters.Add(new SqlParameter(PatientSchema.resultParameterName, SqlDbType.Int));
                    patientDischargeCommand.Parameters[PatientSchema.resultParameterName].Direction = ParameterDirection.Output;

                    await patientDischargeCommand.ExecuteNonQueryAsync();

                    commandResult = Convert.ToInt32(patientDischargeCommand.Parameters[PatientSchema.resultParameterName].Value);         
                }
                catch (Exception ex)
                {
                    throw new Exception($"{CoreConstants.PatientDischargeError}:{commandResult}", ex);
                }
            }

            return commandResult;
        }

        private SqlParameter[] CreateAdmitPatientParam(Patient patient)
        {
            List<SqlParameter> admitPatientParameters = new List<SqlParameter>
            {
                new SqlParameter(PatientSchema.FirstParameterName, patient.FirstName),
                new SqlParameter(PatientSchema.MiddleParameterName, patient.MiddleName),
                new SqlParameter(PatientSchema.LastParameterName, patient.LastName),
                new SqlParameter(PatientSchema.EidParameterName,patient.Eid),
                new SqlParameter(PatientSchema.VdateParameterName, patient.Vdate),
                new SqlParameter(PatientSchema.RcountParameterName, patient.Rcount),
                new SqlParameter(PatientSchema.GenderParameterName, patient.Gender),
                new SqlParameter(PatientSchema.DialysisRenalEndstageParameterName, patient.Dialysisrenalendstage),
                new SqlParameter(PatientSchema.asthmaParameterName, patient.Asthma),
                new SqlParameter(PatientSchema.irondefParameterName, patient.Irondef),
                new SqlParameter(PatientSchema.pneumParameterName, patient.Pneum),
                new SqlParameter(PatientSchema.substancedependenceParameterName, patient.Substancedependence),
                new SqlParameter(PatientSchema.psychologicaldisordermajorParameterName, patient.Psychologicaldisordermajor),
                new SqlParameter(PatientSchema.depressParameterName, patient.Depress),
                new SqlParameter(PatientSchema.psychotherParameterName, patient.Psychother),
                new SqlParameter(PatientSchema.fibrosisandotherParameterName, patient.Fibrosisandother),
                new SqlParameter(PatientSchema.malnutritionParameterName, patient.Malnutrition),
                new SqlParameter(PatientSchema.hemoParameterName, patient.Hemo),
                new SqlParameter(PatientSchema.hematocritParameterName, patient.Hematocrit),
                new SqlParameter(PatientSchema.neutrophilsParameterName, patient.Neutrophils),
                new SqlParameter(PatientSchema.sodiumParameterName, patient.Sodium),
                new SqlParameter(PatientSchema.glucoseParameterName, patient.Glucose),
                new SqlParameter(PatientSchema.bloodureanitroParameterName, patient.Bloodureanitro),
                new SqlParameter(PatientSchema.creatinineParameterName, patient.Creatinine),
                new SqlParameter(PatientSchema.bmiParameterName, patient.Bmi),
                new SqlParameter(PatientSchema.pulseParameterName, patient.Pulse),
                new SqlParameter(PatientSchema.respirationParameterName, patient.Respiration),
                new SqlParameter(PatientSchema.secondarydiagnosisnonicd9ParameterName, patient.Secondarydiagnosisnonicd9),
                new SqlParameter(PatientSchema.facidParameterName, patient.Facid),
                new SqlParameter(PatientSchema.predictedLengthOfStayParameterName,patient.PredictedLengthOfStay),
                new SqlParameter(PatientSchema.resultParameterName,SqlDbType.Int)
            };
            return admitPatientParameters.ToArray();
        }

        /// <summary>
        /// Get Patient using id
        /// </summary>
        /// <param name="encounterId">encounter id</param>
        /// <returns>patient</returns>
        public async Task<Patient> GetPatient(int encounterId)
        {
            Patient patient = new Patient();

            using (var patientConnection =
               new SqlConnection(SqlEncryptionHelper.BuildPatientDbConnection(this.patientDbConnectionStr)))
            {
                await patientConnection.OpenAsync();

                var getPatientCommand = new SqlCommand
                {
                    CommandType = CommandType.Text,
                    Connection = patientConnection,
                    CommandText = $"select [FirstName],[MiddleName],[LastName],[eid],[gender],[vdate],[lengthofstay],[discharged] from [PatientData] where eid={encounterId}"
                };

                var patientReader = await getPatientCommand.ExecuteReaderAsync();

                while (patientReader.Read())
                {
                    var firstName = patientReader.GetString(0);
                    var MiddleName = patientReader.GetString(1);
                    var lastName = patientReader.GetString(2);
                    var eid = patientReader.GetInt32(3);
                    var gender = patientReader.GetString(4);
                    var admissionDate = patientReader.GetDateTime(5);

                    var lengthOfStay = 0;
                    if (!patientReader.IsDBNull(6))
                    {
                        lengthOfStay = patientReader.GetInt32(6);
                    }
                    
                    var discharged = DateTime.Now;
                    if (!patientReader.IsDBNull(7))
                    {
                        discharged = patientReader.GetDateTime(7);
                    }

                    patient.Eid = eid;
                    patient.FirstName = firstName;
                    patient.MiddleName = MiddleName;
                    patient.LastName = lastName;
                    patient.Gender = gender;
                    patient.Vdate = admissionDate;
                    patient.Lengthofstay = lengthOfStay;
                    patient.Discharged = discharged;
                }
            }

            return patient;
        }
    }


}
