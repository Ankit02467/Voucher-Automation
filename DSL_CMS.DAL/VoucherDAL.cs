using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DSL_CMS.DAL
{
    public class VoucherDAL
    {
        #region Provider Summary (voucher-status.aspx)

        /// <summary>
        /// Provider wise Used / Unused(EE) summary for the Voucher Status screen.
        /// </summary>
        /// <summary>
        /// Dashboard grid. One count column driven by <paramref name="status"/>
        /// (blank or "All" = every voucher). <paramref name="days"/> narrows the
        /// Unused count to vouchers lapsing within that many days.
        /// </summary>
        public static DataTable GetProviderSummary(string status, string days, string category,
            string fromDate, string toDate)
        {
            return GetProviderSummary(status, days, category, fromDate, toDate,
                string.Empty, string.Empty);
        }

        /// <summary>
        /// <paramref name="assignedTo"/> and <paramref name="isMoved"/> must match
        /// whatever View Data will apply for the same role, or the dashboard
        /// promises a number the next screen cannot show.
        /// </summary>
        public static DataTable GetProviderSummary(string status, string days, string category,
            string fromDate, string toDate, string assignedTo, string isMoved)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherProvider_Table", true,
                "@Action", "SelectSummary",
                "@Status", status,
                "@Days", days,
                "@Category", category,
                "@FromDate", fromDate,
                "@ToDate", toDate,
                "@AssignedTo", assignedTo,
                "@IsMoved", isMoved);
        }

        public static DataTable GetAllProvider()
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherProvider_Table", true, "@Action", "SelectDropdown");
        }

        /// <summary>
        /// Figures for the cards across the top of the dashboard, scoped the same
        /// way as the grid beneath them.
        /// </summary>
        public static DataTable GetDashboardTotals(string assignedTo, string isMoved)
        {
            return GetDashboardTotals(assignedTo, isMoved, string.Empty);
        }

        /// <summary>
        /// <paramref name="category"/> narrows the cards to one provider category,
        /// the same way the sidebar narrows the grid beneath them. Blank means
        /// every category, which is what the two-argument overload asks for.
        /// </summary>
        public static DataTable GetDashboardTotals(string assignedTo, string isMoved, string category)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherProvider_Table", true,
                "@Action", "SelectDashboardTotals",
                "@AssignedTo", assignedTo,
                "@IsMoved", isMoved,
                "@Category", category);
        }

        public static DataTable GetProvider(string Id)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherProvider_Table", true, "@Action", "SelectId", "@Id", Id);
        }

        /// <summary>
        /// Adds a provider and hands back its new id, so the screen that created
        /// it can go straight on to adding products against it.
        /// </summary>
        public static int InsertProvider(string name, string category, string status)
        {
            return Convert.ToInt32(SqlHelper.ExecuteScalar("Sp_VoucherProvider_Table", true,
                "@Action", "Insert",
                "@Name", name,
                "@Category", category,
                "@Status", status));
        }

        /// <summary>
        /// Every category, for the chips at the top of the menu. Read on its own
        /// rather than off the provider list, which is narrowed by the chip that
        /// is lit - picking one would otherwise leave no way back to the others.
        /// </summary>
        public static DataTable GetProviderCategories()
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherProvider_Table", true, "@Action", "SelectCategory");
        }

        #endregion

        #region Voucher (voucher-data.aspx)

        public static DataTable GetVoucherDetail(string providerId, string productId, string voucherCode,
            string dealerName, string checkDate, string checkedBy, string status, string actn)
        {
            return GetVoucherDetail(providerId, productId, voucherCode, dealerName,
                checkDate, checkedBy, status, string.Empty, string.Empty, string.Empty, actn);
        }

        /// <summary>
        /// View Data grid. <paramref name="assignedTo"/> restricts the rows to one
        /// student's vouchers; <paramref name="isMoved"/> is "0" for still-open rows,
        /// "1" for the ones a student has already moved on. <paramref name="days"/> is
        /// the early-expiry window carried over from the dashboard - only vouchers
        /// lapsing within that many days come back. Blank means no restriction.
        /// </summary>
        public static DataTable GetVoucherDetail(string providerId, string productId, string voucherCode,
            string dealerName, string checkDate, string checkedBy, string status,
            string assignedTo, string isMoved, string days, string actn)
        {
            return GetVoucherDetail(providerId, productId, voucherCode, dealerName, checkDate,
                checkedBy, status, assignedTo, isMoved, days, string.Empty, actn);
        }

        /// <summary><paramref name="expiryDate"/> matches one exact expiry date; blank means any.</summary>
        public static DataTable GetVoucherDetail(string providerId, string productId, string voucherCode,
            string dealerName, string checkDate, string checkedBy, string status,
            string assignedTo, string isMoved, string days, string expiryDate, string actn)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", actn,
                "@ProviderId", providerId,
                "@ProductId", productId,
                "@VoucherCode", voucherCode,
                "@DealerName", dealerName,
                "@VoucherCheckDate", checkDate,
                "@CheckedBy", checkedBy,
                "@Status", status,
                "@AssignedTo", assignedTo,
                "@IsMoved", isMoved,
                "@Days", days,
                "@ExpiryDate", expiryDate);
        }

        /// <summary>Highest dealer slot in use - drives how many dealer columns the grid shows.</summary>
        public static DataTable GetDealerColumns(string providerId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "SelectDealerColumns",
                "@ProviderId", providerId);
        }

        #region View Data screen

        /// <summary>Upload Entry modal - pastes many codes at once. Rows split by '~', fields by '|'.</summary>
        public static DataTable BulkInsert(string productId, string data, string addedBy)
        {
            return BulkInsert(productId, data, string.Empty, addedBy);
        }

        /// <summary>
        /// <paramref name="dealerData"/> carries the dealer pairs pasted beside
        /// each voucher, as "code|seq|name|saledate" records separated by ~.
        /// Both dates must already be ISO - see NormaliseDate on voucher-data.
        /// </summary>
        public static DataTable BulkInsert(string productId, string data, string dealerData, string addedBy)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "BulkInsert",
                "@ProductId", productId,
                "@Data", data,
                "@DealerData", dealerData,
                "@AddedBy", addedBy);
        }

        /// <summary>
        /// Voucher team - replaces the whole dealer list for one voucher.
        /// <paramref name="data"/> is "name|date~name|date~..." in column order.
        /// </summary>
        public static void SaveDealers(string id, string data, string userId)
        {
            SqlHelper.ExecuteNonQuery("Sp_VoucherStock_Table", true,
                "@Action", "SaveDealers",
                "@Id", id,
                "@Data", data,
                "@AddedBy", userId);
        }

        /// <summary>
        /// Admin edit - expiry date, check date, status and used date. The voucher
        /// code, added by, candidate name and exam details are shown to the admin
        /// but are not editable, and the proc will not change them.
        /// </summary>
        public static DataTable UpdateAdminEntry(string id, string expiryDate,
            string checkDate, string status, string usedDate, string userId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "UpdateAdminEntry",
                "@Id", id,
                "@ExpiryDate", expiryDate,
                "@VoucherCheckDate", checkDate,
                "@Status", status,
                "@UsedDate", usedDate,
                "@AddedBy", userId);
        }

        /// <summary>Student - hands a finished voucher over to the sub-admin.</summary>
        public static DataTable Move(string id, string userId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "Move",
                "@Id", id,
                "@AddedBy", userId);
        }

        /// <summary>Sub-admin - sends a moved voucher back to a student.</summary>
        public static DataTable Reassign(string id, string assignedTo, string userId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "Reassign",
                "@Id", id,
                "@AssignedTo", assignedTo,
                "@AddedBy", userId);
        }

        /// <summary>Sub-admin - sends a batch of moved vouchers back to one student.</summary>
        public static DataTable ReassignMany(string ids, string assignedTo, string userId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "ReassignMany",
                "@Ids", ids,
                "@AssignedTo", assignedTo,
                "@AddedBy", userId);
        }

        /// <summary>
        /// Moves every voucher whose midnight has passed over to the sub-admin.
        /// Safe to call on every page load - it is idempotent and normally a
        /// no-op. LocalDB has no SQL Agent, so there is no scheduled job to do it.
        /// </summary>
        public static int AutoMove()
        {
            DataTable dt = SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "AutoMove");

            return (dt != null && dt.Rows.Count > 0) ? Convert.ToInt32(dt.Rows[0]["Moved"]) : 0;
        }

        /// <summary>
        /// Student status buttons. Touches Status and UsedDate only, leaving
        /// candidate and exam details alone - the student is never shown those
        /// fields, so a full status update would blank them.
        /// </summary>
        /// <summary>
        /// Returns the voucher id, or -3 when the voucher is not assigned to
        /// <paramref name="userId"/>. The id reaches us from a hidden field, so
        /// the proc re-checks ownership and this is how it reports a refusal.
        /// </summary>
        public static int UpdateStatusOnly(string id, string status, string usedDate,
            string checkedBy, string userId)
        {
            object result = SqlHelper.ExecuteScalar("Sp_VoucherStock_Table", true,
                "@Action", "UpdateStatusOnly",
                "@Id", id,
                "@Status", status,
                "@UsedDate", usedDate,
                "@CheckedBy", checkedBy,
                "@AddedBy", userId);

            return (result == null || result == DBNull.Value) ? 0 : Convert.ToInt32(result);
        }

        /// <summary>Student / sub-admin - status entry. Check date and CheckedBy are stamped in the proc.</summary>
        public static void UpdateStatusEntry(string id, string status, string usedDate,
            string candidateName, string examDate, string examMode, string checkedBy, string userId)
        {
            SqlHelper.ExecuteNonQuery("Sp_VoucherStock_Table", true,
                "@Action", "UpdateStatusEntry",
                "@Id", id,
                "@Status", status,
                "@UsedDate", usedDate,
                "@CandidateName", candidateName,
                "@ExamDate", examDate,
                "@ExamMode", examMode,
                "@CheckedBy", checkedBy,
                "@AddedBy", userId);
        }

        /// <summary>Unassigned vouchers offered in the "+ Assign" modal.</summary>
        public static DataTable GetForAssign(string providerId, string productId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "SelectForAssign",
                "@ProviderId", providerId,
                "@ProductId", productId);
        }

        /// <summary>
        /// Done entries offered in the same modal when the sub-admin is looking at
        /// the done list. Same picker, different set.
        /// </summary>
        public static DataTable GetForReassign(string providerId, string productId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "SelectForReassign",
                "@ProviderId", providerId,
                "@ProductId", productId);
        }

        public static DataTable Assign(string ids, string assignedTo, string userId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "Assign",
                "@Ids", ids,
                "@AssignedTo", assignedTo,
                "@AddedBy", userId);
        }

        /// <summary>Admin - "View History" modal.</summary>
        public static DataTable GetHistory(string providerId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "SelectHistory",
                "@ProviderId", providerId);
        }

        /// <summary>
        /// The life of one voucher, oldest first: who assigned it, who checked
        /// it and when, who reassigned it, and so on round again.
        /// </summary>
        public static DataTable GetVoucherHistory(string voucherId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "SelectVoucherHistory",
                "@Id", voucherId);
        }

        /// <summary>Voucher module role of the signed-in user (blank when not mapped).</summary>
        public static DataTable GetUserRole(string userId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherUser_Table", true,
                "@Action", "SelectRole", "@UserId", userId);
        }

        public static DataTable GetStudents()
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherUser_Table", true, "@Action", "SelectStudents");
        }

        #endregion

        #region Performance

        /// <summary>
        /// One student's checked-voucher counts, split by provider. Drives the
        /// student's own Voucher Status screen.
        /// </summary>
        public static DataTable GetPerformanceByProvider(string userId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherPerformance_Table", true,
                "@Action", "SelectByProvider",
                "@UserId", userId);
        }

        /// <summary>
        /// Every student's checked-voucher counts, optionally narrowed to one
        /// provider. Drives the admin / sub-admin "Student wise performance" screen.
        /// </summary>
        public static DataTable GetPerformanceByStudent(string providerId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherPerformance_Table", true,
                "@Action", "SelectByStudent",
                "@ProviderId", providerId);
        }

        /// <summary>
        /// Checked-voucher counts per provider, by anyone. Top level of the
        /// Product wise performance screen.
        /// </summary>
        public static DataTable GetProviderChecks()
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherPerformance_Table", true,
                "@Action", "SelectProviderChecks");
        }

        /// <summary>The same, split by product - what a provider row expands into.</summary>
        public static DataTable GetProductChecks(string providerId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherPerformance_Table", true,
                "@Action", "SelectProductChecks",
                "@ProviderId", providerId);
        }

        #endregion

        public static DataTable GetData(string Id)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true, "@Action", "SelectId", "@Id", Id);
        }

        /* InsertVoucherDetail / UpdateVoucherDetail lived here and were removed.

           UpdateVoucherDetail called @Action = 'Update', which the proc has never
           had since Revision 2 - so it fell through every branch and did nothing,
           silently and without error. Nothing called either method.

           Both also took dealerName and saleDate, which the proc stopped reading
           once dealers moved to VoucherDealer_Table; a caller would have believed
           it was saving a dealer that was quietly dropped.

           Vouchers are created through BulkInsert and edited through
           UpdateAdminEntry / UpdateStatusEntry / UpdateStatusOnly. If a
           single-voucher insert is ever wanted, write it against the current
           schema rather than reviving this. */

        /// <summary>
        /// Marks a voucher as checked (Voucher Check Date / Checked By columns).
        /// <paramref name="userId"/> must be passed: it lands in
        /// VoucherHistory_Table.ChangedBy, which is what the performance screens
        /// count. Without it the check is recorded against nobody.
        /// </summary>
        public static void UpdateVoucherCheck(string Id, string checkedBy, string userId)
        {
            SqlHelper.ExecuteNonQuery("Sp_VoucherStock_Table", true,
                "@Action", "UpdateCheck",
                "@Id", Id,
                "@CheckedBy", checkedBy,
                "@AddedBy", userId);
        }

        /// <summary>
        /// Names offered by the "Checked By" filter. Scoped to one provider -
        /// offering a name whose checks are all on another provider gives a filter
        /// that can only return nothing. Blank means every provider.
        /// </summary>
        public static DataTable GetCheckedByList(string providerId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "SelectCheckedBy",
                "@ProviderId", providerId);
        }

        public static DataTable GetVoucherCount(string providerId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true, "@Action", "SelectCount", "@ProviderId", providerId);
        }

        #endregion

        #region Product (manage-product.aspx)

        public static DataTable GetProductDetail(string providerId, string srch, string actn)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherProduct_Table", true,
                "@Action", actn,
                "@ProviderId", providerId,
                "@Search", srch);
        }

        public static DataTable GetProductById(string Id)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherProduct_Table", true, "@Action", "SelectId", "@Id", Id);
        }

        public static int InsertProductDetail(string providerId, string name, string validityDays, string status)
        {
            return Convert.ToInt32(SqlHelper.ExecuteScalar("Sp_VoucherProduct_Table", true,
                "@Action", "Insert",
                "@ProviderId", providerId,
                "@Name", name,
                "@ValidityDays", validityDays,
                "@Status", status));
        }

        public static void UpdateProductDetail(string Id, string providerId, string name, string validityDays, string status)
        {
            SqlHelper.ExecuteNonQuery("Sp_VoucherProduct_Table", true,
                "@Action", "Update",
                "@Id", Id,
                "@ProviderId", providerId,
                "@Name", name,
                "@ValidityDays", validityDays,
                "@Status", status);
        }

        #endregion
    }
}
