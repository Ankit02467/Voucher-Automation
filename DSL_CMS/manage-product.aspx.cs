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
        protected Panel pnlMsg;
        protected Literal litMsg;

        protected void Page_Load(object sender, EventArgs e)
        {
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
