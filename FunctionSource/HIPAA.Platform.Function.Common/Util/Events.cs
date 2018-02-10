using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace HIPAA.Platform.Function.Common
{
    public static class Events
    {
        public static string BlobCreatedEvent = "Microsoft.Storage.BlobCreated";

        public static string PatientAdmissionEvent = "admissionRecord";

        public static string PatientDischargeEvent = "dischargeRecord";
    }
}
