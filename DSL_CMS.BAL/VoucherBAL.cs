using DSL_CMS.DAL;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DSL_CMS.BAL
{
    public class VoucherBAL
    {
        #region Provider Summary

        public static DataTable GetProviderSummary(string status, string days, string category,
            string fromDate, string toDate)
        {
            return VoucherDAL.GetProviderSummary(status, days, category, fromDate, toDate);
        }

        public static DataTable GetProviderSummary(string status, string days, string category,
            string fromDate, string toDate, string assignedTo, string isMoved)
        {
            return VoucherDAL.GetProviderSummary(status, days, category, fromDate, toDate,
                assignedTo, isMoved);
        }

        public static DataTable GetAllProvider()
        {
            return VoucherDAL.GetAllProvider();
        }

        public static DataTable GetDashboardTotals(string assignedTo, string isMoved)
        {
            return VoucherDAL.GetDashboardTotals(assignedTo, isMoved);
        }

        public static DataTable GetDashboardTotals(string assignedTo, string isMoved, string category)
        {
            return VoucherDAL.GetDashboardTotals(assignedTo, isMoved, category);
        }

        public static DataTable GetProviderCategories()
        {
            return VoucherDAL.GetProviderCategories();
        }

        public static int InsertProvider(string name, string category, string status)
        {
            return VoucherDAL.InsertProvider(name, category, status);
        }

        public static DataTable GetProvider(string Id)
        {
            return VoucherDAL.GetProvider(Id);
        }

        #endregion

        #region Voucher

        public static DataTable GetVoucherDetail(string providerId, string productId, string voucherCode,
            string dealerName, string checkDate, string checkedBy, string status, string actn)
        {
            return VoucherDAL.GetVoucherDetail(providerId, productId, voucherCode, dealerName, checkDate, checkedBy, status, actn);
        }

        public static DataTable GetVoucherDetail(string providerId, string productId, string voucherCode,
            string dealerName, string checkDate, string checkedBy, string status,
            string assignedTo, string isMoved, string days, string actn)
        {
            return VoucherDAL.GetVoucherDetail(providerId, productId, voucherCode, dealerName,
                checkDate, checkedBy, status, assignedTo, isMoved, days, actn);
        }

        public static DataTable GetVoucherDetail(string providerId, string productId, string voucherCode,
            string dealerName, string checkDate, string checkedBy, string status,
            string assignedTo, string isMoved, string days, string expiryDate, string actn)
        {
            return VoucherDAL.GetVoucherDetail(providerId, productId, voucherCode, dealerName,
                checkDate, checkedBy, status, assignedTo, isMoved, days, expiryDate, actn);
        }

        public static DataTable GetDealerColumns(string providerId)
        {
            return VoucherDAL.GetDealerColumns(providerId);
        }

        public static DataTable GetData(string Id)
        {
            return VoucherDAL.GetData(Id);
        }

        #region View Data screen

        public static DataTable BulkInsert(string productId, string data, string addedBy)
        {
            return VoucherDAL.BulkInsert(productId, data, addedBy);
        }

        public static DataTable BulkInsert(string productId, string data, string dealerData, string addedBy)
        {
            return VoucherDAL.BulkInsert(productId, data, dealerData, addedBy);
        }

        public static void SaveDealers(string id, string data, string userId)
        {
            VoucherDAL.SaveDealers(id, data, userId);
        }

        public static DataTable UpdateAdminEntry(string id, string expiryDate,
            string checkDate, string status, string usedDate,
            string candidateName, string examDate, string examMode, string userId)
        {
            return VoucherDAL.UpdateAdminEntry(id, expiryDate, checkDate, status, usedDate,
                candidateName, examDate, examMode, userId);
        }

        public static DataTable Move(string id, string userId)
        {
            return VoucherDAL.Move(id, userId);
        }

        public static DataTable Reassign(string id, string assignedTo, string userId)
        {
            return VoucherDAL.Reassign(id, assignedTo, userId);
        }

        public static DataTable ReassignMany(string ids, string assignedTo, string userId)
        {
            return VoucherDAL.ReassignMany(ids, assignedTo, userId);
        }

        public static int AutoMove()
        {
            return VoucherDAL.AutoMove();
        }

        public static int UpdateStatusOnly(string id, string status, string usedDate,
            string checkedBy, string userId)
        {
            return VoucherDAL.UpdateStatusOnly(id, status, usedDate, checkedBy, userId);
        }

        public static void UpdateStatusEntry(string id, string status, string usedDate,
            string candidateName, string examDate, string examMode, string checkedBy, string userId)
        {
            VoucherDAL.UpdateStatusEntry(id, status, usedDate, candidateName, examDate, examMode, checkedBy, userId);
        }

        public static DataTable GetForAssign(string providerId, string productId)
        {
            return VoucherDAL.GetForAssign(providerId, productId);
        }

        public static DataTable GetForReassign(string providerId, string productId)
        {
            return VoucherDAL.GetForReassign(providerId, productId);
        }

        public static DataTable Assign(string ids, string assignedTo, string userId)
        {
            return VoucherDAL.Assign(ids, assignedTo, userId);
        }

        public static DataTable GetHistory(string providerId)
        {
            return VoucherDAL.GetHistory(providerId);
        }

        public static DataTable GetVoucherHistory(string voucherId)
        {
            return VoucherDAL.GetVoucherHistory(voucherId);
        }

        public static DataTable GetUserRole(string userId)
        {
            return VoucherDAL.GetUserRole(userId);
        }

        public static DataTable GetStudents()
        {
            return VoucherDAL.GetStudents();
        }

        #endregion

        #region Performance

        public static DataTable GetPerformanceByProvider(string userId)
        {
            return VoucherDAL.GetPerformanceByProvider(userId);
        }

        public static DataTable GetPerformanceByStudent(string providerId)
        {
            return VoucherDAL.GetPerformanceByStudent(providerId);
        }

        public static DataTable GetProviderChecks()
        {
            return VoucherDAL.GetProviderChecks();
        }

        public static DataTable GetProductChecks(string providerId)
        {
            return VoucherDAL.GetProductChecks(providerId);
        }

        #endregion

        /* InsertVoucherDetail / UpdateVoucherDetail removed - see VoucherDAL. */

        public static void UpdateVoucherCheck(string Id, string checkedBy, string userId)
        {
            VoucherDAL.UpdateVoucherCheck(Id, checkedBy, userId);
        }

        public static DataTable GetCheckedByList(string providerId)
        {
            return VoucherDAL.GetCheckedByList(providerId);
        }

        public static DataTable GetVoucherCount(string providerId)
        {
            return VoucherDAL.GetVoucherCount(providerId);
        }

        #endregion

        #region Product

        public static DataTable GetProductDetail(string providerId, string srch, string actn)
        {
            return VoucherDAL.GetProductDetail(providerId, srch, actn);
        }

        public static DataTable GetProductById(string Id)
        {
            return VoucherDAL.GetProductById(Id);
        }

        public static int InsertProductDetail(string providerId, string name, string validityDays, string status)
        {
            return VoucherDAL.InsertProductDetail(providerId, name, validityDays, status);
        }

        public static void UpdateProductDetail(string Id, string providerId, string name, string validityDays, string status)
        {
            VoucherDAL.UpdateProductDetail(Id, providerId, name, validityDays, status);
        }

        #endregion
    }
}
