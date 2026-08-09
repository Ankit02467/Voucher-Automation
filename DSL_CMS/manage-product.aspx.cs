using DSL_CMS.BAL;
using System;
using System.Data;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace DSL_CMS
{
    public partial class manage_product : System.Web.UI.Page
    {
        protected HiddenField hfId;
        protected DropDownList ddlProvider;
        protected TextBox txtName;
        protected TextBox txtValidityDays;
        protected DropDownList ddlStatus;
        protected Button btnSave;
        protected Button btnCancel;
        protected Literal litFormTitle;

        protected DropDownList ddlFilterProvider;
        protected TextBox txtSearch;
        protected Button btnSearch;
        protected Button btnReset;

        protected Repeater rptProduct;
        protected PlaceHolder phEmpty;
        protected Literal litCount;
        protected Panel pnlMsg, pnlBody, pnlDenied;
        protected Literal litMsg;

        private const string RoleAdmin = "Voucher Admin";

        /// <summary>
        /// Resolved from the database on every request, not cached in ViewState -
        /// a posted-back role is a role the caller can edit.
        /// </summary>
        private bool IsAdmin
        {
            get
            {
                DataTable dt = VoucherBAL.GetUserRole(Convert.ToString(Session["UserId"]));

                string role = (dt != null && dt.Rows.Count > 0)
                    ? Convert.ToString(dt.Rows[0]["RoleName"]).Trim()
                    : string.Empty;

                // Unmapped users fall back to admin, matching the other screens.
                return role.Length == 0 || role == RoleAdmin;
            }
        }

        /// <summary>
        /// Back to Voucher Status with the provider, so its row reopens there and
        /// the anchor restores the scroll. Read from the query string, which is
        /// how this screen is reached from the dashboard.
        /// </summary>
        protected string BackUrl
        {
            get
            {
                string url = ResolveUrl("~/voucher-status.aspx");
                string provider = (Request.QueryString["providerId"] ?? string.Empty).Trim();

                if (provider.Length == 0) return url;
                return url + "?providerId=" + Server.UrlEncode(provider) + "#prov-" + provider;
            }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            // Hiding the "Manage Product" link on Voucher Status is not a gate -
            // the URL is guessable and every handler below is a write. Anyone who
            // is not an admin gets nothing to work with, on every request.
            if (!IsAdmin)
            {
                pnlBody.Visible = false;
                pnlDenied.Visible = true;
                return;
            }

            if (!IsPostBack)
            {
                BindProviders();

                // Deep link from voucher-status.aspx -> "Manage Product"
                string providerId = Request.QueryString["providerId"];
                if (!string.IsNullOrEmpty(providerId))
                {
                    SelectIfPresent(ddlFilterProvider, providerId);
                    SelectIfPresent(ddlProvider, providerId);
                }

                BindGrid();
            }
        }

        private void BindProviders()
        {
            DataTable dt = VoucherBAL.GetAllProvider();

            ddlProvider.Items.Clear();
            ddlProvider.Items.Add(new ListItem("-- Select Provider --", string.Empty));

            ddlFilterProvider.Items.Clear();
            ddlFilterProvider.Items.Add(new ListItem("-- All --", string.Empty));

            if (dt == null) return;
            foreach (DataRow r in dt.Rows)
            {
                string id = Convert.ToString(r["Id"]);
                string name = Convert.ToString(r["Name"]);
                ddlProvider.Items.Add(new ListItem(name, id));
                ddlFilterProvider.Items.Add(new ListItem(name, id));
            }
        }

        private void BindGrid()
        {
            DataTable dt = VoucherBAL.GetProductDetail(
                ddlFilterProvider.SelectedValue,
                txtSearch.Text.Trim(),
                "Select");

            rptProduct.DataSource = dt;
            rptProduct.DataBind();

            int count = (dt == null) ? 0 : dt.Rows.Count;
            litCount.Text = count.ToString();
            phEmpty.Visible = (count == 0);
        }

        protected void btnSearch_Click(object sender, EventArgs e)
        {
            BindGrid();
        }

        protected void btnReset_Click(object sender, EventArgs e)
        {
            ddlFilterProvider.SelectedIndex = 0;
            txtSearch.Text = string.Empty;
            BindGrid();
        }

        protected void btnSave_Click(object sender, EventArgs e)
        {
            if (!IsAdmin) return;   // never write on the strength of a hidden button

            if (ddlProvider.SelectedValue.Length == 0 || txtName.Text.Trim().Length == 0)
            {
                ShowMessage("Provider and Product Name are required.", false);
                return;
            }

            try
            {
                if (Convert.ToInt32(hfId.Value) == 0)
                {
                    int newId = VoucherBAL.InsertProductDetail(
                        ddlProvider.SelectedValue,
                        txtName.Text.Trim(),
                        txtValidityDays.Text.Trim(),
                        ddlStatus.SelectedValue);

                    if (newId == -1)
                    {
                        ShowMessage("This product already exists for the selected provider.", false);
                        return;
                    }
                    ShowMessage("Product added successfully.", true);
                }
                else
                {
                    VoucherBAL.UpdateProductDetail(
                        hfId.Value,
                        ddlProvider.SelectedValue,
                        txtName.Text.Trim(),
                        txtValidityDays.Text.Trim(),
                        ddlStatus.SelectedValue);

                    ShowMessage("Product updated successfully.", true);
                }

                ClearForm();
                BindGrid();
            }
            catch (Exception ex)
            {
                ShowMessage("Save failed: " + ex.Message, false);
            }
        }

        protected void btnCancel_Click(object sender, EventArgs e)
        {
            ClearForm();
        }

        protected void rptProduct_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (!IsAdmin) return;
            if (e.CommandName != "EditRow") return;

            DataTable dt = VoucherBAL.GetProductById(Convert.ToString(e.CommandArgument));
            if (dt == null || dt.Rows.Count == 0) return;

            DataRow r = dt.Rows[0];
            hfId.Value = Convert.ToString(r["Id"]);
            SelectIfPresent(ddlProvider, Convert.ToString(r["ProviderId"]));
            txtName.Text = Convert.ToString(r["Name"]);
            txtValidityDays.Text = Convert.ToString(r["ValidityDays"]);
            SelectIfPresent(ddlStatus, Convert.ToString(r["Status"]));

            litFormTitle.Text = "Edit Product (#" + hfId.Value + ")";
        }

        private void ClearForm()
        {
            hfId.Value = "0";
            ddlProvider.SelectedIndex = 0;
            txtName.Text = string.Empty;
            txtValidityDays.Text = string.Empty;
            ddlStatus.SelectedIndex = 0;
            litFormTitle.Text = "Add Product";
        }

        private static void SelectIfPresent(ListControl list, string value)
        {
            ListItem item = list.Items.FindByValue(value);
            if (item != null) list.SelectedValue = value;
        }

        private void ShowMessage(string message, bool success)
        {
            litMsg.Text = Server.HtmlEncode(message);
            pnlMsg.CssClass = success ? "msg msg-ok" : "msg msg-bad";
            pnlMsg.Visible = true;
        }
    }
}
