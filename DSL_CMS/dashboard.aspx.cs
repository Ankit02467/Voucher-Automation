using DSL_CMS.BAL;
using System;
using System.Data;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace DSL_CMS
{
    public partial class dashboard : System.Web.UI.Page
    {
        protected Literal litTotal;
        protected Literal litUsed;
        protected Literal litUnused;
        protected Literal litExpired;
        protected Literal litChecked;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (IsPostBack) return;

            DataTable dt = VoucherBAL.GetVoucherCount(string.Empty);
            if (dt == null || dt.Rows.Count == 0) return;

            DataRow r = dt.Rows[0];
            litTotal.Text = Convert.ToString(r["TotalVoucher"]);
            litUsed.Text = Convert.ToString(r["UsedVoucher"]);
            litUnused.Text = Convert.ToString(r["UnusedVoucher"]);
            litExpired.Text = Convert.ToString(r["ExpiredVoucher"]);
            litChecked.Text = Convert.ToString(r["CheckedVoucher"]);
        }
    }
}
