using DSL_CMS.BAL;
using System;
using System.Configuration;
using System.Data;

namespace DSL_CMS.Helpers
{
    /// <summary>
    /// Which voucher role the signed-in user has, and what to do when they have
    /// none.
    ///
    /// Seven screens used to answer that question themselves, and all seven
    /// answered it the same way: a user with no voucher role mapped was treated
    /// as <see cref="Admin"/>. That was deliberate, for testing, and it is
    /// listed as a known gap in DEPLOYMENT.md section 8 - but it means every
    /// account that can sign into the site at all gets the run of the voucher
    /// module, including Upload Entry and Add Provider. On the staging database
    /// that was 43 users, none of them mapped.
    ///
    /// The rule now lives here, once, and defaults to refusing. A developer who
    /// wants the old behaviour opts into it explicitly:
    ///
    ///     &lt;add key="VoucherUnmappedIsAdmin" value="true" /&gt;
    ///
    /// The default is the safe one, so a server that never sets the key is
    /// closed rather than open - the setting has to be added to weaken it, not
    /// remembered to keep it strong.
    /// </summary>
    public static class VoucherAccess
    {
        public const string Admin    = "Voucher Admin";
        public const string SubAdmin = "Voucher Sub Admin";
        public const string Team     = "Voucher Team";
        public const string Student  = "Voucher Student";

        private const string UnmappedKey = "VoucherUnmappedIsAdmin";

        /// <summary>
        /// Whether a user with no voucher role is treated as admin. False
        /// unless Web.config says otherwise, so the omission is the safe case.
        /// </summary>
        public static bool UnmappedIsAdmin
        {
            get
            {
                bool on;
                return bool.TryParse(ConfigurationManager.AppSettings[UnmappedKey], out on) && on;
            }
        }

        /// <summary>
        /// The role mapped to this user, or an empty string if there is none.
        ///
        /// Looked up fresh every time rather than cached in ViewState: a role
        /// the caller can post back is not a permission. The pages that want to
        /// avoid the round trip cache the *result* of <see cref="Effective"/>
        /// in Session, which the caller cannot edit.
        /// </summary>
        public static string Mapped(object userId)
        {
            try
            {
                DataTable dt = VoucherBAL.GetUserRole(Convert.ToString(userId));
                return (dt != null && dt.Rows.Count > 0)
                    ? Convert.ToString(dt.Rows[0]["RoleName"]).Trim()
                    : string.Empty;
            }
            catch
            {
                // A failed lookup is not permission to continue. MasterPage used
                // to swallow this and fall through to admin.
                return string.Empty;
            }
        }

        /// <summary>
        /// The role to act on: the mapped one, or - only when the setting above
        /// allows it - <see cref="Admin"/>. Empty means no access, and the
        /// caller must refuse.
        /// </summary>
        /// <param name="unmapped">
        /// True when nothing was mapped, whatever this returns. View Data shows
        /// its role-preview dropdown on this, which is only reachable when the
        /// fallback is switched on.
        /// </param>
        public static string Effective(object userId, out bool unmapped)
        {
            string role = Mapped(userId);
            unmapped = role.Length == 0;

            if (!unmapped) return role;
            return UnmappedIsAdmin ? Admin : string.Empty;
        }

        /// <summary>Convenience for the screens that only care about admin.</summary>
        public static bool IsAdmin(object userId)
        {
            bool unmapped;
            return Effective(userId, out unmapped) == Admin;
        }

        /// <summary>True when the user may not use the voucher module at all.</summary>
        public static bool IsDenied(object userId)
        {
            bool unmapped;
            return Effective(userId, out unmapped).Length == 0;
        }
    }
}
