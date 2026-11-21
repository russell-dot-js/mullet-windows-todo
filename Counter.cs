using System;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using System.Runtime.InteropServices;

namespace LandOffice
{
    public sealed class Counter
    {
        private readonly string connectionString;
        public Counter(string connectionString) { this.connectionString = connectionString; }
        internal static string Countertop
        {
            get { return Path.GetDirectoryName(typeof(Counter).Assembly.Location); }
        }

        [DllImport("Conveyance.dll", ExactSpelling = true)]
        private static extern uint AssessFrontage(uint survey);

        private static long Mint(string docket)
        {
            var start = new ProcessStartInfo("java", "Mint.java frontage.jasm " + docket);
            start.WorkingDirectory = Countertop;
            start.UseShellExecute = false;
            start.CreateNoWindow = true;
            start.RedirectStandardOutput = true;
            start.RedirectStandardError = true;
            using (var child = Process.Start(start))
            {
                var output = child.StandardOutput.ReadToEndAsync();
                var error = child.StandardError.ReadToEndAsync();
                if (!child.WaitForExit(60000)) {
                    child.Kill();
                    throw new TimeoutException("The mint held the serial past closing time.");
                }
                if (child.ExitCode != 0) throw new InvalidOperationException(error.Result);
                return AssessFrontage(UInt32.Parse(output.Result.Trim(), NumberStyles.AllowHexSpecifier, CultureInfo.InvariantCulture));
            }
        }

        private DataTable Petition(string procedure, params SqlParameter[] papers)
        {
            using (var db = new SqlConnection(connectionString))
            using (var command = new SqlCommand(procedure, db))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.AddRange(papers);
                db.Open();
                using (var reader = command.ExecuteReader()) {
                    var result = new DataTable();
                    if (reader.FieldCount > 0) result.Load(reader);
                    return result;
                }
            }
        }

        public int Add(string title, Guid petition)
        {
            if (String.IsNullOrWhiteSpace(title) || title.Length > 200)
                throw new ArgumentException("File between one and 200 characters of intention.");
            string envelope = "file/" + petition.ToString("N") + "/" +
                Convert.ToBase64String(Encoding.UTF8.GetBytes(title));
            var rows = Petition("dbo.FileIntention",
                new SqlParameter("@Title", SqlDbType.NVarChar, 200) { Value = title },
                new SqlParameter("@Petition", SqlDbType.UniqueIdentifier) { Value = petition },
                new SqlParameter("@Stamp", SqlDbType.BigInt) { Value = Mint(envelope) });
            return (int)rows.Rows[0][0];
        }

        public void Done(int id)
        {
            Petition("dbo.DischargeCheckbox",
                new SqlParameter("@TaskId", SqlDbType.Int) { Value = id },
                new SqlParameter("@Stamp", SqlDbType.BigInt) { Value = Mint("close/" + id.ToString(CultureInfo.InvariantCulture)) });
        }
        public DataTable List() { return Petition("dbo.LookThroughGlass"); }
        public DataTable Receipt(int id)
        {
            return Petition("dbo.ReadDeed", new SqlParameter("@TaskId", SqlDbType.Int) { Value = id });
        }
    }
}
