using DSL_CMS.BAL;
using System;
using System.Data;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace DSL_CMS
{
    /// <summary>
    /// Student wise performance - how many vouchers each student has checked
    /// today, over the last 7 days and over the last 30 days. Admin and
    /// sub-admin only; a provider filter narrows every column at once.
    /// </summary>
    public partial class student_performance : System.Web.UI.Page
    {
        protected Repeater rptProvider, rptPerformance;
        protected PlaceHolder phEmpty;
        protected Panel pnlBody, pnlDenied;
        protected Literal litRole;

        private const string RoleAdmin = "Voucher Admin";
        private const string RoleSubAdmin = "Voucher Sub Admin";

        /// <summary>Blank means every provider.</summary>
        private string SelectedProvider
        {
            get { return (string)(ViewState["Provider"] ?? string.Empty); }
            set { ViewState["Provider"] = value; }
        }

        private string Role
        {
            get { return (string)(ViewState["Role"] ?? string.Empty); }
            set { ViewState["Role"] = value; }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (IsPostBack) return;

            ResolveRole();
            litRole.Text = Server.HtmlEncode(Role);

            // Sub-admin sees this screen too - it is not admin-only.
            bool allowed = (Role == RoleAdmin || Role == RoleSubAdmin);
            pnlBody.Visible = allowed;
            pnlDenied.Visible = !allowed;
            if (!allowed) return;

            BindProviders();
            BindGrid();
        }

        /// <summary>
        /// Same fallback the other screens use: a user with no voucher role
        /// mapped is treated as admin.
        /// </summary>
        private void ResolveRole()
        {
            DataTable dt = VoucherBAL.GetUserRole(Convert.ToString(Session["UserId"]));

            string role = (dt != null && dt.Rows.Count > 0)
                ? Convert.ToString(dt.Rows[0]["RoleName"]).Trim()
                : string.Empty;

            Role = (role.Length == 0) ? RoleAdmin : role;
        }

        private void BindProviders()
        {
            var items = new System.Collections.Generic.List<ListItem>();
            items.Add(new ListItem("All", string.Empty));

            DataTable dt = VoucherBAL.GetAllProvider();
            if (dt != null)
                foreach (DataRow r in dt.Rows)
                    items.Add(new ListItem(Convert.ToString(r["Name"]), Convert.ToString(r["Id"])));

            rptProvider.DataSource = items;
            rptProvider.DataBind();
        }

        private void BindGrid()
        {
            DataTable dt = VoucherBAL.GetPerformanceByStudent(SelectedProvider);

            rptPerformance.DataSource = dt;
            rptPerformance.DataBind();

            phEmpty.Visible = (dt == null || dt.Rows.Count == 0);
        }

        protected void rptProvider_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName != "PickProvider") return;

            SelectedProvider = Convert.ToString(e.CommandArgument);

            BindProviders();
            BindGrid();
        }

        protected string ProviderPillClass(object providerId)
        {
            return string.Equals(Convert.ToString(providerId), SelectedProvider, StringComparison.Ordinal)
                ? "pill-btn on"
                : "pill-btn";
        }
    }
}
