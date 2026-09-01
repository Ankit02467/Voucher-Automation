using DSL_CMS.BAL;
using DSL_CMS.Helpers;
using System;
using System.Data;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace DSL_CMS
{
    /// <summary>
    /// Adds a provider, then its products, on one screen - and adds a product to
    /// a provider that is already here, which is the same screen with step one
    /// answered a different way.
    ///
    /// Two steps rather than one form: a product row needs a ProviderId, so the
    /// provider has to exist before any product can be saved. Holding the
    /// products in memory until a final Save would lose the lot on any slip,
    /// and would need a second copy of the duplicate handling Manage Product
    /// already has.
    ///
    /// Step two never cared where the id came from, so picking an existing
    /// provider opens exactly what saving a new one opens. That is the whole of
    /// the change: no second screen, no second copy of the product form.
    /// </summary>
    public partial class add_provider : System.Web.UI.Page
    {
        protected TextBox txtName, txtNewCategory, txtProductName;
        protected DropDownList ddlCategory, ddlStatus, ddlProductStatus, ddlExistingProvider;
        protected Button btnSaveProvider, btnStartOver, btnAddProduct;
        protected Panel pnlBody, pnlDenied, pnlMsg, pnlProducts,
                        pnlMode, pnlNewProvider, pnlPickProvider;
        protected LinkButton lnkModeNew, lnkModeExisting;
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
                // VoucherAccess decides what an unmapped user gets; by default
                // that is nothing. See Helpers/VoucherAccess.cs.
                return VoucherAccess.IsAdmin(Session["UserId"]);
            }
        }

        /// <summary>
        /// The provider step two is working on - saved just now, or picked from
        /// the ones already here. Step two cannot tell the difference and does
        /// not need to.
        /// </summary>
        private string NewProviderId
        {
            get { return (string)(ViewState["NewProvider"] ?? string.Empty); }
            set { ViewState["NewProvider"] = value; }
        }

        /// <summary>
        /// True while the screen is adding a product to a provider that already
        /// exists. False is the original job, making a new one.
        /// </summary>
        private bool PickMode
        {
            get { return (bool)(ViewState["PickMode"] ?? false); }
            set { ViewState["PickMode"] = value; }
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

            if (!IsPostBack)
            {
                BindCategories();

                // Arriving from a provider's row - "add a product to this one" -
                // rather than from the "+" in the menu. The screen opens on that
                // provider with its products already listed.
                string providerId = (Request.QueryString["providerId"] ?? string.Empty).Trim();
                if (providerId.Length > 0)
                {
                    PickMode = true;
                    BindProviders();
                    SelectIfPresent(ddlExistingProvider, providerId);
                    ApplyMode();
                    OpenPickedProvider();
                    return;
                }

                ApplyMode();
            }
        }

        #region Which of the two jobs

        protected void lnkModeNew_Click(object sender, EventArgs e)
        {
            // Back to a blank form. Redirecting rather than clearing by hand:
            // step one locks itself once a provider has been saved, and there
            // are more fields to put back than there are worth remembering.
            Response.Redirect(Request.Path, true);
        }

        protected void lnkModeExisting_Click(object sender, EventArgs e)
        {
            if (!IsAdmin) return;

            PickMode = true;
            NewProviderId = string.Empty;
            pnlProducts.Visible = false;
            pnlMsg.Visible = false;

            BindProviders();
            ApplyMode();

            // Open on whichever provider the list starts with, so the screen
            // shows what it can do rather than an empty half of a form.
            OpenPickedProvider();
        }

        /// <summary>Which half of step one is showing, and which button is lit.</summary>
        private void ApplyMode()
        {
            pnlPickProvider.Visible = PickMode;
            pnlNewProvider.Visible = !PickMode;

            lnkModeNew.CssClass = PickMode ? "pill-btn" : "pill-btn on";
            lnkModeExisting.CssClass = PickMode ? "pill-btn on" : "pill-btn";

            litStepOne.Text = PickMode ? "1. Choose a provider" : "1. Provider details";
        }

        /// <summary>
        /// The providers a product can be added to - the same list Manage Product
        /// offers, which is the active ones. A retired provider keeps the
        /// vouchers it already has, but giving it a new product is not something
        /// this screen should make easy.
        /// </summary>
        private void BindProviders()
        {
            DataTable dt = VoucherBAL.GetAllProvider();

            ddlExistingProvider.Items.Clear();
            if (dt == null) return;

            foreach (DataRow r in dt.Rows)
                ddlExistingProvider.Items.Add(
                    new ListItem(Convert.ToString(r["Name"]), Convert.ToString(r["Id"])));
        }

        protected void ddlExistingProvider_SelectedIndexChanged(object sender, EventArgs e)
        {
            if (!IsAdmin) return;

            pnlMsg.Visible = false;
            OpenPickedProvider();
        }

        /// <summary>Hands the picked provider to step two, which is the same step
        /// two a newly saved provider gets.</summary>
        private void OpenPickedProvider()
        {
            if (ddlExistingProvider.Items.Count == 0) return;

            NewProviderId = ddlExistingProvider.SelectedValue;
            OpenProducts(ddlExistingProvider.SelectedItem.Text);
        }

        private static void SelectIfPresent(ListControl list, string value)
        {
            ListItem item = list.Items.FindByValue(value ?? string.Empty);
            if (item != null) list.SelectedValue = value;
        }

        #endregion

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
            litProviderName.Text = Server.HtmlEncode(providerName);

            // Only the new-provider half locks. Picking from the list is a
            // choice you are meant to be able to change, and there is nothing
            // there to lock: the dropdown is the whole of step one.
            if (!PickMode)
            {
                litStepOne.Text = "1. Provider details &mdash; saved";

                txtName.Enabled = false;
                ddlCategory.Enabled = false;
                txtNewCategory.Enabled = false;
                ddlStatus.Enabled = false;
                txtName.CssClass = "locked";
                ddlCategory.CssClass = "locked";
                txtNewCategory.CssClass = "locked";

                btnSaveProvider.Visible = false;
                btnStartOver.Visible = true;
            }

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
