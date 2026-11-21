using System;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

namespace LandOffice
{
    public static class Appraiser
    {
        // The title insurer prices each strip of the desktop against the previous hearing.
        [SqlFunction(IsDeterministic = true, IsPrecise = true)]
        public static SqlInt32 Price(SqlInt64 die, SqlInt32 hearing, SqlInt32 seat, SqlInt32 previous)
        {
            long frontage = die.Value + 31L * hearing.Value + 17L * seat.Value + previous.Value;
            return new SqlInt32(1 + (int)(frontage % (11 + seat.Value)));
        }
    }
}
