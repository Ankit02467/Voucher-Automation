using DSL_CMS.BAL;
using System;
using System.Collections.Generic;
using System.Data;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace DSL_CMS
{
    /// <summary>
    /// Product wise performance - how many vouchers were checked per provider,
    /// and per product once a provider row is opened. Counts work done on the
    /// stock, regardless of who did it. Admin only.
    /// </summary>
    public partial class product_performance : System.Web.UI.Page
    {
        protected Repeater rptProviders;
        protected PlaceHolder phEmpty;
        protected Panel pnlBody, pnlDenied;
        protected Literal litRole;

        private const string RoleAdmin = "Voucher Admin";

        /// <summary>Provider whose product breakdown is currently open, if any.</summary>
        private string ExpandedProvider
        {
            get { return (string)(ViewState["Expanded"] ?? string.Empty); }
            set { ViewState["Expanded"] = value; }
        }

        /// <summary>
        /// Read from the database on every request rather than cached in
        /// ViewState - a role the caller can post back is not a permission.
        /// </summary>
        private bool IsAdmin
        {
            get
            {
                DataTable dt = VoucherBAL.GetUserRole(Convert.ToString(Session["UserId"]));

                string role = (dt != null && dt.Rows.Count > 0)
                    ? Convert.ToString(dt.Rows[0]["RoleName"]).Trim()
                    : string.Empty;

                // Unmapped users fall back to admin, as on every other screen.
                return role.Length == 0 || role == RoleAdmin;
            }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsAdmin)
            {
                pnlBody.Visible = false;
                pnlDenied.Visible = true;
                litRole.Text = "No access";
                return;
            }

            if (IsPostBack) return;

            litRole.Text = RoleAdmin;
            BindGrid();
        }

        private void BindGrid()
        {
            DataTable dt = VoucherBAL.GetProviderChecks();

            rptProviders.DataSource = dt;
            rptProviders.DataBind();

            phEmpty.Visible = (dt == null || dt.Rows.Count == 0);
        }

        protected void rptProviders_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (!IsAdmin) return;
            if (e.CommandName != "ToggleProducts") return;

            string id = Convert.ToString(e.CommandArgument);
            ExpandedProvider = (ExpandedProvider == id) ? string.Empty : id;

            BindGrid();
        }

        protected bool IsExpanded(object providerId)
        {
            return string.Equals(Convert.ToString(providerId), ExpandedProvider, StringComparison.Ordinal);
        }

        protected string ChevronClass(object providerId)
        {
            return IsExpanded(providerId) ? "chev-icon open" : "chev-icon";
        }

        /// <summary>
        /// Products of one provider with their own three figures. The markup binds
        /// to this twice - once for the rows, once to decide whether to show the
        /// empty message - so the result is held rather than fetched again.
        /// </summary>
        private readonly Dictionary<string, DataTable> _productCache =
            new Dictionary<string, DataTable>(StringComparer.Ordinal);

        protected DataTable ProductChecks(object providerId)
        {
            string key = Convert.ToString(providerId);

            DataTable dt;
            if (!_productCache.TryGetValue(key, out dt))
            {
                dt = VoucherBAL.GetProductChecks(key);
                _productCache[key] = dt;
            }
            return dt;
        }

        protected bool HasProducts(object providerId)
        {
            DataTable dt = ProductChecks(providerId);
            return dt != null && dt.Rows.Count > 0;
        }
    }
}
