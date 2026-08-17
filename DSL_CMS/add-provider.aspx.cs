using DSL_CMS.BAL;
using System;
using System.Data;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace DSL_CMS
{
    /// <summary>
    /// Adds a provider, then its products, on one screen.
    ///
    /// Two steps rather than one form: a product row needs a ProviderId, so the
    /// provider has to exist before any product can be saved. Holding the
    /// products in memory until a final Save would lose the lot on any slip,
    /// and would need a second copy of the duplicate handling Manage Product
    /// already has.
    /// </summary>
    public partial class add_provider : System.Web.UI.Page
    {
        protected TextBox txtName, txtNewCategory, txtProductName;
        protected DropDownList ddlCategory, ddlStatus, ddlProductStatus;
        protected Button btnSaveProvider, btnStartOver, btnAddProduct;
        protected Panel pnlBody, pnlDenied, pnlMsg, pnlProducts;
        protected Literal litMsg, litStepOne, litProviderName, litCount;
        protected Repeater rptProduct;
        protected PlaceHolder phEmpty;
        protected HyperLink lnkViewData, lnkManage;

        private const string RoleAdmin = "Voucher Admin";

        /// <summary>The dropdown entry that reveals the box for a name of your own.</summary>
        private const string NewCategory = "__new";

        /// <summary>
        /// Resolved from the database on every request, not cached in ViewState -
        /// a posted-back role is a role the caller can edit. Same rule as
        /// Manage Product, which is the other screen that writes here.
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

        /// <summary>The provider saved in step one; blank until then.</summary>
        private string NewProviderId
        {
            get { return (string)(ViewState["NewProvider"] ?? string.Empty); }
            set { ViewState["NewProvider"] = value; }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            // Hiding the "+" in the menu is not a gate - the URL is guessable and
            // both handlers below are writes. Checked on every request.
            if (!IsAdmin)
            {
                pnlBody.Visible = false;
                pnlDenied.Visible = true;
                return;
            }

            if (!IsPostBack) BindCategories();
        }

        /// <summary>
        /// The categories already in use. Picking from them is what keeps the
        /// filter chips on Voucher Status from splitting in two the first time
        /// someone types "it" where "IT" already exists.
        /// </summary>
        private void BindCategories()
        {
            ddlCategory.Items.Clear();
            ddlCategory.Items.Add(new ListItem("-- None --", string.Empty));

            DataTable dt = VoucherBAL.GetProviderCategories();
            if (dt != null)
            {
                foreach (DataRow r in dt.Rows)
                {
                    string name = Convert.ToString(r["Category"]).Trim();
                    if (name.Length > 0) ddlCategory.Items.Add(new ListItem(name, name));
                }
            }

            ddlCategory.Items.Add(new ListItem("+ New category...", NewCategory));
        }

        protected void ddlCategory_SelectedIndexChanged(object sender, EventArgs e)
        {
            txtNewCategory.Visible = (ddlCategory.SelectedValue == NewCategory);
            if (!txtNewCategory.Visible) txtNewCategory.Text = string.Empty;
        }

        /// <summary>Whichever of the two the dropdown is pointing at.</summary>
        private string ChosenCategory
        {
            get
            {
                return (ddlCategory.SelectedValue == NewCategory)
                    ? txtNewCategory.Text.Trim()
                    : ddlCategory.SelectedValue;
            }
        }

        protected void btnSaveProvider_Click(object sender, EventArgs e)
        {
            if (!IsAdmin) return;   // never write on the strength of a hidden button

            string name = txtName.Text.Trim();
            if (name.Length == 0)
            {
                ShowMessage("Provider Name is required.", false);
                return;
            }

            if (ddlCategory.SelectedValue == NewCategory && ChosenCategory.Length == 0)
            {
                ShowMessage("Type the new category, or pick one from the list.", false);
                return;
            }

            try
            {
                int newId = VoucherBAL.InsertProvider(name, ChosenCategory, ddlStatus.SelectedValue);

                if (newId == -1)
                {
                    ShowMessage("A provider called \"" + name + "\" already exists.", false);
                    return;
                }

                NewProviderId = newId.ToString();
                ShowMessage("Provider added. Now add its products below.", true);

                OpenProducts(name);
            }
            catch (Exception ex)
            {
                ShowMessage("Save failed: " + ex.Message, false);
            }
        }

        /// <summary>
        /// Step one closes once it has been saved. Editing the name here after
        /// the fact would save a second provider, not rename the first.
        /// </summary>
        private void OpenProducts(string providerName)
        {
            litStepOne.Text = "1. Provider details &mdash; saved";
            litProviderName.Text = Server.HtmlEncode(providerName);

            txtName.Enabled = false;
            ddlCategory.Enabled = false;
            txtNewCategory.Enabled = false;
            ddlStatus.Enabled = false;
            txtName.CssClass = "locked";
            ddlCategory.CssClass = "locked";
            txtNewCategory.CssClass = "locked";

            btnSaveProvider.Visible = false;
            btnStartOver.Visible = true;

            lnkViewData.NavigateUrl = ResolveUrl("~/voucher-data.aspx?providerId=") + NewProviderId;
            lnkManage.NavigateUrl = ResolveUrl("~/manage-product.aspx?providerId=") + NewProviderId;

            pnlProducts.Visible = true;
            BindProducts();
        }

        protected void btnAddProduct_Click(object sender, EventArgs e)
        {
            if (!IsAdmin || NewProviderId.Length == 0) return;

            string name = txtProductName.Text.Trim();
            if (name.Length == 0)
            {
                ShowMessage("Product Name is required.", false);
                return;
            }

            try
            {
                // The same call Manage Product makes, duplicate rule and all.
                // Validity is left blank here - it is not asked for on this
                // screen, and Manage Product is where it gets filled in.
                int newId = VoucherBAL.InsertProductDetail(
                    NewProviderId, name, string.Empty, ddlProductStatus.SelectedValue);

                if (newId == -1)
                {
                    ShowMessage("This product already exists for this provider.", false);
                    return;
                }

                ShowMessage("Product added.", true);

                txtProductName.Text = string.Empty;
                ddlProductStatus.SelectedIndex = 0;

                BindProducts();
            }
            catch (Exception ex)
            {
                ShowMessage("Save failed: " + ex.Message, false);
            }
        }

        private void BindProducts()
        {
            DataTable dt = VoucherBAL.GetProductDetail(NewProviderId, string.Empty, "Select");

            rptProduct.DataSource = dt;
            rptProduct.DataBind();

            int count = (dt == null) ? 0 : dt.Rows.Count;
            litCount.Text = count.ToString();
            phEmpty.Visible = (count == 0);
        }

        /// <summary>Back to an empty form for the next provider.</summary>
        protected void btnStartOver_Click(object sender, EventArgs e)
        {
            Response.Redirect(Request.Path, true);
        }

        private void ShowMessage(string message, bool success)
        {
            litMsg.Text = Server.HtmlEncode(message);
            pnlMsg.CssClass = success ? "msg msg-ok" : "msg msg-bad";
            pnlMsg.Visible = true;
        }
    }
}
