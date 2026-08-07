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
            return SqlHelper.ExecuteDataTable("Sp_VoucherProvider_Table", true,
                "@Action", "SelectSummary",
                "@Status", status,
                "@Days", days,
                "@Category", category,
                "@FromDate", fromDate,
                "@ToDate", toDate);
        }

        public static DataTable GetAllProvider()
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherProvider_Table", true, "@Action", "SelectDropdown");
        }

        public static DataTable GetProvider(string Id)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherProvider_Table", true, "@Action", "SelectId", "@Id", Id);
        }

        #endregion

        #region Voucher (voucher-data.aspx)

        public static DataTable GetVoucherDetail(string providerId, string productId, string voucherCode,
            string dealerName, string checkDate, string checkedBy, string status, string actn)
        {
            return GetVoucherDetail(providerId, productId, voucherCode, dealerName,
                checkDate, checkedBy, status, string.Empty, string.Empty, actn);
        }

        /// <summary>
        /// View Data grid. <paramref name="assignedTo"/> restricts the rows to one
        /// student's vouchers; <paramref name="isMoved"/> is "0" for still-open rows,
        /// "1" for the ones a student has already moved on. Blank means no restriction.
        /// </summary>
        public static DataTable GetVoucherDetail(string providerId, string productId, string voucherCode,
            string dealerName, string checkDate, string checkedBy, string status,
            string assignedTo, string isMoved, string actn)
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
                "@IsMoved", isMoved);
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
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "BulkInsert",
                "@ProductId", productId,
                "@Data", data,
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
        /// Admin edit - voucher code, expiry date and check date only.
        /// Returns -1 for a duplicate code, -2 when the code is blank.
        /// </summary>
        public static DataTable UpdateAdminEntry(string id, string voucherCode,
            string expiryDate, string checkDate, string userId)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true,
                "@Action", "UpdateAdminEntry",
                "@Id", id,
                "@VoucherCode", voucherCode,
                "@ExpiryDate", expiryDate,
                "@VoucherCheckDate", checkDate,
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

        public static DataTable GetData(string Id)
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true, "@Action", "SelectId", "@Id", Id);
        }

        public static int InsertVoucherDetail(string providerId, string productId, string voucherCode,
            string expiryDate, string dealerName, string saleDate, string status, string addedBy)
        {
            return Convert.ToInt32(SqlHelper.ExecuteScalar("Sp_VoucherStock_Table", true,
                "@Action", "Insert",
                "@ProviderId", providerId,
                "@ProductId", productId,
                "@VoucherCode", voucherCode,
                "@ExpiryDate", expiryDate,
                "@DealerName", dealerName,
                "@SaleDate", saleDate,
                "@Status", status,
                "@AddedBy", addedBy));
        }

        public static void UpdateVoucherDetail(string Id, string providerId, string productId, string voucherCode,
            string expiryDate, string dealerName, string saleDate, string status, string modifiedBy)
        {
            SqlHelper.ExecuteNonQuery("Sp_VoucherStock_Table", true,
                "@Action", "Update",
                "@Id", Id,
                "@ProviderId", providerId,
                "@ProductId", productId,
                "@VoucherCode", voucherCode,
                "@ExpiryDate", expiryDate,
                "@DealerName", dealerName,
                "@SaleDate", saleDate,
                "@Status", status,
                "@AddedBy", modifiedBy);
        }

        /// <summary>
        /// Marks a voucher as checked (Voucher Check Date / Checked By columns).
        /// </summary>
        public static void UpdateVoucherCheck(string Id, string checkedBy)
        {
            SqlHelper.ExecuteNonQuery("Sp_VoucherStock_Table", true,
                "@Action", "UpdateCheck",
                "@Id", Id,
                "@CheckedBy", checkedBy);
        }

        public static DataTable GetCheckedByList()
        {
            return SqlHelper.ExecuteDataTable("Sp_VoucherStock_Table", true, "@Action", "SelectCheckedBy");
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
