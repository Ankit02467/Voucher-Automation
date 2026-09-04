using DSL_CMS.BAL;
using DSL_CMS.Helpers;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace DSL_CMS
{
    /// <summary>
    /// Student wise performance, for the admin and the sub-admin.
    ///
    /// One row per student *and provider*, because a student can be holding
    /// vouchers of two providers at once and those are two different piles of
    /// work. The student's name is written once above its own run of rows
    /// rather than repeated down the column - and when a sort breaks the run
    /// up, each row carries its own name again, because a name that appears
    /// once is only readable while the rows underneath it belong to it.
    ///
    /// The figures are the same five the student sees on their own screen, and
    /// they answer two different questions:
    ///
    ///   All / Checked / Pending - what is in that student's hands right now
    ///       for that provider. Counted from the voucher rows themselves, so
    ///       All is exactly Checked + Pending and the totals across the screen
    ///       add up. Checked is AutoMoveAfter being set: the stamp goes on when
    ///       a status is saved and comes off again on an assign or a reassign,
    ///       so it is the set the overnight sweep will actually move.
    ///
    ///   Weekly / Monthly - how much that student has checked for that provider
    ///       over the last 7 and 30 days, from the history log. A voucher
    ///       checked yesterday has left the first three and is still counted
    ///       here.
    ///
    /// A provider is listed for a student only if they are holding something of
    /// it, and a product only if they are holding one of those. Nothing on this
    /// screen is a link: it answers "who has what" and does not send anyone
    /// anywhere.
    /// </summary>
    public partial class student_performance : System.Web.UI.Page
    {
        protected Repeater rptPerformance;
        protected PlaceHolder phEmpty;
        protected Panel pnlBody, pnlDenied;
        protected LinkButton lnkSortStudent, lnkSortProvider, lnkSortAll,
                             lnkSortChecked, lnkSortPending, lnkSortWeekly, lnkSortMonthly;
        protected Literal litSortStudent, litSortProvider, litSortAll,
                          litSortChecked, litSortPending, litSortWeekly, litSortMonthly,
                          litTotalAll, litTotalChecked, litTotalPending;

        private const string RoleAdmin = "Voucher Admin";
        private const string RoleSubAdmin = "Voucher Sub Admin";

        /// <summary>The columns, and the order they are read in by default.</summary>
        private const string ByStudent = "StudentName";
        private const string ByProvider = "ProviderName";
        private const string ByAll = "AllCount";
        private const string ByChecked = "CheckedCount";
        private const string ByPending = "PendingCount";
        private const string ByWeekly = "Weekly";
        private const string ByMonthly = "Monthly";

        private string Role
        {
            get { return (string)(ViewState["Role"] ?? string.Empty); }
            set { ViewState["Role"] = value; }
        }

        private string SortKey
        {
            get { return (string)(ViewState["Sort"] ?? ByStudent); }
            set { ViewState["Sort"] = value; }
        }

        private bool SortDesc
        {
            get { return (bool)(ViewState["SortDesc"] ?? false); }
            set { ViewState["SortDesc"] = value; }
        }

        /// <summary>
        /// Which rows have their products open, as a delimited list of
        /// "student:provider" keys. Keyed on both halves rather than on the
        /// provider alone: two students can be holding CompTIA, and opening one
        /// of them must not open the other's row as well.
        /// </summary>
        private string Expanded
        {
            get { return (string)(ViewState["Open"] ?? string.Empty); }
            set { ViewState["Open"] = value; }
        }

        private const char ExpandedSep = ',';

        protected void Page_Load(object sender, EventArgs e)
        {
            if (IsPostBack) return;

            ResolveRole();

            // Sub-admin sees this screen too - it is not admin-only.
            bool allowed = (Role == RoleAdmin || Role == RoleSubAdmin);
            pnlBody.Visible = allowed;
            pnlDenied.Visible = !allowed;
            if (!allowed) return;

            BindGrid();
        }

        /// <summary>
        /// The caller's role, blank when they have none - which the caller
        /// treats as denied. Helpers/VoucherAccess.cs holds the rule.
        /// </summary>
        private void ResolveRole()
        {
            bool unmapped;
            Role = VoucherAccess.Effective(Session["UserId"], out unmapped);
        }

        private void BindGrid()
        {
            DataTable dt = BuildTable();

            ApplyTotals(dt);
            dt = ApplySort(dt);
            ApplyHeads();

            _lastStudent = null;
            rptPerformance.DataSource = dt;
            rptPerformance.DataBind();

            phEmpty.Visible = (dt == null || dt.Rows.Count == 0);
        }

        #region Building the table

        /// <summary>
        /// The shape of the table, on its own so every early return hands back
        /// something the repeater and the sorter can both read.
        ///
        /// The product columns are pipe separated strings sharing one order, the
        /// way the other two tables carry theirs - index N of each is the same
        /// product. A nested Repeater cannot break out of its parent's cell to
        /// line up with these columns, so the sub-rows are emitted whole by
        /// ProductRows.
        /// </summary>
        private static DataTable EmptyTable()
        {
            var t = new DataTable();
            t.Columns.Add("Key", typeof(string));
            t.Columns.Add("StudentId", typeof(string));
            t.Columns.Add(ByStudent, typeof(string));
            t.Columns.Add("ProviderId", typeof(string));
            t.Columns.Add(ByProvider, typeof(string));
            t.Columns.Add(ByAll, typeof(int));
            t.Columns.Add(ByChecked, typeof(int));
            t.Columns.Add(ByPending, typeof(int));
            t.Columns.Add(ByWeekly, typeof(int));
            t.Columns.Add(ByMonthly, typeof(int));
            t.Columns.Add("ProductCount", typeof(int));
            t.Columns.Add("ProductNames", typeof(string));
            t.Columns.Add("ProductAll", typeof(string));
            t.Columns.Add("ProductChecked", typeof(string));
            t.Columns.Add("ProductPending", typeof(string));
            return t;
        }

        /// <summary>
        /// Every voucher a student is holding, in one read, grouped by student
        /// and provider and then by product inside that.
        ///
        /// One fetch rather than one per student: the same call the student's
        /// own screen makes, with the student left off. That is what keeps the
        /// two screens agreeing - a figure here and the same figure on their
        /// Voucher Status come from one query under one set of filters.
        /// </summary>
        private DataTable BuildTable()
        {
            DataTable table = EmptyTable();

            DataTable held;
            try
            {
                held = VoucherBAL.GetVoucherDetail(string.Empty, string.Empty, string.Empty,
                    string.Empty, string.Empty, string.Empty, string.Empty,
                    string.Empty, "0", string.Empty, "SelectAll");
            }
            catch
            {
                return table;
            }

            if (held == null || held.Rows.Count == 0) return table;

            var order = new List<string>();
            var row = new Dictionary<string, string[]>();     // key -> student id, name, provider id, name
            var all = new Dictionary<string, int>();
            var done = new Dictionary<string, int>();

            var prodOrder = new Dictionary<string, List<string>>();
            var prodName = new Dictionary<string, string>();
            var prodAll = new Dictionary<string, int>();
            var prodDone = new Dictionary<string, int>();

            foreach (DataRow v in held.Rows)
            {
                // Unassigned stock belongs to nobody, so it is not on anybody's
                // row. It is still counted on the Voucher Status screen, which
                // is the one that answers "what is in the cupboard".
                string student = Convert.ToString(v["AssignedTo"]);
                if (student.Length == 0) continue;

                string provider = Convert.ToString(v["ProviderId"]);
                if (provider.Length == 0) continue;

                string key = student + ":" + provider;
                if (!all.ContainsKey(key))
                {
                    order.Add(key);
                    row[key] = new string[]
                    {
                        student,
                        Convert.ToString(v["AssignedToName"]),
                        provider,
                        Convert.ToString(v["ProviderName"])
                    };
                    all[key] = 0;
                    done[key] = 0;
                    prodOrder[key] = new List<string>();
                }

                // Checked is the overnight stamp, for the reason the student's
                // own screen uses it: it is put on by a save and taken off again
                // by an assign or a reassign, so it says "done, and leaving
                // tonight" without asking who did it or reading a date.
                bool ticked = v["AutoMoveAfter"] != DBNull.Value;

                all[key]++;
                if (ticked) done[key]++;

                string product = Convert.ToString(v["ProductId"]);
                if (product.Length == 0) continue;

                string pkey = key + ":" + product;
                if (!prodAll.ContainsKey(pkey))
                {
                    prodOrder[key].Add(product);
                    prodName[pkey] = Convert.ToString(v["ProductName"]);
                    prodAll[pkey] = 0;
                    prodDone[pkey] = 0;
                }

                prodAll[pkey]++;
                if (ticked) prodDone[pkey]++;
            }

            Dictionary<string, int[]> history = HistoryCounts(row);

            foreach (string key in order)
            {
                string[] who = row[key];

                List<string> prods = prodOrder[key];
                string owner = key;
                prods.Sort(delegate(string a, string b)
                {
                    return string.Compare(prodName[owner + ":" + a], prodName[owner + ":" + b],
                        StringComparison.OrdinalIgnoreCase);
                });

                var pn = new List<string>();
                var pa = new List<string>();
                var pc = new List<string>();
                var pp = new List<string>();

                foreach (string product in prods)
                {
                    string pkey = key + ":" + product;
                    pn.Add(prodName[pkey]);
                    pa.Add(prodAll[pkey].ToString());
                    pc.Add(prodDone[pkey].ToString());
                    pp.Add((prodAll[pkey] - prodDone[pkey]).ToString());
                }

                int[] window = history.ContainsKey(key) ? history[key] : new int[] { 0, 0 };

                DataRow r = table.NewRow();
                r["Key"] = key;
                r["StudentId"] = who[0];
                r[ByStudent] = who[1];
                r["ProviderId"] = who[2];
                r[ByProvider] = who[3];
                r[ByAll] = all[key];
                r[ByChecked] = done[key];
                r[ByPending] = all[key] - done[key];
                r[ByWeekly] = window[0];
                r[ByMonthly] = window[1];
                r["ProductCount"] = pn.Count;
                r["ProductNames"] = string.Join("|", pn.ToArray());
                r["ProductAll"] = string.Join("|", pa.ToArray());
                r["ProductChecked"] = string.Join("|", pc.ToArray());
                r["ProductPending"] = string.Join("|", pp.ToArray());
                table.Rows.Add(r);
            }

            return table;
        }

        /// <summary>
        /// Weekly and monthly for every student:provider pair on the screen.
        ///
        /// The performance proc answers "every student, for one provider", so
        /// this asks it once per provider that actually appears - a handful of
        /// calls, not one per student. Providers nobody is holding anything of
        /// are never asked about, because they have no row to fill.
        /// </summary>
        private Dictionary<string, int[]> HistoryCounts(Dictionary<string, string[]> rows)
        {
            var found = new Dictionary<string, int[]>();

            var providers = new List<string>();
            foreach (string[] who in rows.Values)
                if (!providers.Contains(who[2])) providers.Add(who[2]);

            foreach (string provider in providers)
            {
                DataTable dt;
                try
                {
                    dt = VoucherBAL.GetPerformanceByStudent(provider);
                }
                catch
                {
                    // The history counts are the softer half of the row. Losing
                    // them must not take the held figures - the ones somebody
                    // acts on - off the screen too; they read nought instead.
                    continue;
                }

                if (dt == null) continue;

                foreach (DataRow r in dt.Rows)
                {
                    string key = Convert.ToString(r["Id"]) + ":" + provider;
                    found[key] = new int[] { Num(r, ByWeekly), Num(r, ByMonthly) };
                }
            }

            return found;
        }

        private static int Num(DataRow r, string column)
        {
            if (!r.Table.Columns.Contains(column)) return 0;

            object v = r[column];
            if (v == null || v == DBNull.Value) return 0;

            int n;
            return int.TryParse(Convert.ToString(v), out n) ? n : 0;
        }

        #endregion

        #region Totals

        /// <summary>
        /// The band above the list: everything on the screen added up, so the
        /// question "how much is out with the students altogether" is answered
        /// without adding the column up by eye. Every row is on the screen, so
        /// it needs no caveat beside it saying which ones it counted.
        ///
        /// Three of the five columns, not all five. Weekly and Monthly count
        /// work got through over a rolling week and a rolling month, and the
        /// same check falls in both - so one figure over every student for
        /// each of two overlapping windows is a number with no question behind
        /// it. The three that are added up are a count of rows held right now,
        /// and adding those is the same act as counting them.
        /// </summary>
        private void ApplyTotals(DataTable dt)
        {
            int all = 0, done = 0, pending = 0;

            if (dt != null)
                foreach (DataRow r in dt.Rows)
                {
                    all += Num(r, ByAll);
                    done += Num(r, ByChecked);
                    pending += Num(r, ByPending);
                }

            litTotalAll.Text = all.ToString();
            litTotalChecked.Text = done.ToString();
            litTotalPending.Text = pending.ToString();
        }

        #endregion

        #region Sorting

        protected void sort_Command(object sender, CommandEventArgs e)
        {
            string key = Convert.ToString(e.CommandArgument);
            if (key != ByStudent && key != ByProvider && key != ByAll && key != ByChecked
             && key != ByPending && key != ByWeekly && key != ByMonthly) return;

            if (string.Equals(key, SortKey, StringComparison.Ordinal))
            {
                SortDesc = !SortDesc;
            }
            else
            {
                SortKey = key;
                // a name starts at A; a count is asked "which is most", so it
                // starts at the largest - the rule the other two tables follow
                SortDesc = (key != ByStudent && key != ByProvider);
            }

            BindGrid();
        }

        /// <summary>
        /// Sorted on one column, and then on the other two text columns, so a
        /// student's providers stay together underneath their name instead of
        /// scattering through the list on every tie.
        /// </summary>
        private DataTable ApplySort(DataTable dt)
        {
            if (dt == null || dt.Rows.Count == 0) return dt;

            string key = SortKey;
            if (!dt.Columns.Contains(key)) key = ByStudent;

            // DataView cannot be told to ignore case, so the two names are
            // compared off shadow columns rather than off themselves -
            // otherwise "aws" and "AWS" land in two different places.
            const string studentShadow = "__StudentSort";
            const string providerShadow = "__ProviderSort";
            AddShadow(dt, studentShadow, ByStudent);
            AddShadow(dt, providerShadow, ByProvider);

            string first = key;
            if (key == ByStudent) first = studentShadow;
            else if (key == ByProvider) first = providerShadow;

            string dir = SortDesc ? " DESC" : " ASC";
            var order = new StringBuilder(first).Append(dir);

            if (key != ByStudent) order.Append(", ").Append(studentShadow).Append(" ASC");
            if (key != ByProvider) order.Append(", ").Append(providerShadow).Append(" ASC");

            try
            {
                var view = new DataView(dt) { Sort = order.ToString() };
                return view.ToTable();
            }
            catch (Exception)
            {
                // a column that will not sort must not take the table down with it
                return dt;
            }
        }

        private static void AddShadow(DataTable dt, string name, string source)
        {
            if (dt.Columns.Contains(name)) return;

            dt.Columns.Add(name, typeof(string));
            foreach (DataRow row in dt.Rows)
                row[name] = Convert.ToString(row[source]).Trim().ToUpperInvariant();
        }

        private void ApplyHeads()
        {
            litSortStudent.Text = Arrow(ByStudent);
            litSortProvider.Text = Arrow(ByProvider);
            litSortAll.Text = Arrow(ByAll);
            litSortChecked.Text = Arrow(ByChecked);
            litSortPending.Text = Arrow(ByPending);
            litSortWeekly.Text = Arrow(ByWeekly);
            litSortMonthly.Text = Arrow(ByMonthly);

            lnkSortStudent.ToolTip = Tip(ByStudent);
            lnkSortProvider.ToolTip = Tip(ByProvider);
            lnkSortAll.ToolTip = Tip(ByAll);
            lnkSortChecked.ToolTip = Tip(ByChecked);
            lnkSortPending.ToolTip = Tip(ByPending);
            lnkSortWeekly.ToolTip = Tip(ByWeekly);
            lnkSortMonthly.ToolTip = Tip(ByMonthly);
        }

        private string Arrow(string key)
        {
            if (!string.Equals(key, SortKey, StringComparison.Ordinal))
                return "<span class=\"sortarrow\">&#8645;</span>";

            return SortDesc ? "<span class=\"sortarrow on\">&#9660;</span>"
                            : "<span class=\"sortarrow on\">&#9650;</span>";
        }

        private string Tip(string key)
        {
            bool active = string.Equals(key, SortKey, StringComparison.Ordinal);
            bool text = (key == ByStudent || key == ByProvider);
            bool nextDesc = active ? !SortDesc : !text;

            if (text) return nextDesc ? "Sort Z to A" : "Sort A to Z";

            return Meaning(key) + (nextDesc ? " - sort highest first" : " - sort lowest first");
        }

        private static string Meaning(string key)
        {
            if (key == ByAll) return "Vouchers this student is holding of this provider";
            if (key == ByChecked) return "Of those, the ones checked - they move to the sub admin tonight";
            if (key == ByPending) return "Of those, the ones still to check";
            if (key == ByWeekly) return "Checked by this student for this provider in the last 7 days";
            if (key == ByMonthly) return "The same over the last 30 days";
            return string.Empty;
        }

        #endregion

        #region Rows

        protected void rptPerformance_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName != "ToggleProducts") return;

            SetOpen(Convert.ToString(e.CommandArgument));
            BindGrid();
        }

        private void SetOpen(string key)
        {
            if (key.Length == 0) return;

            var kept = new List<string>();
            bool was = false;

            foreach (string held in Expanded.Split(ExpandedSep))
            {
                if (held.Length == 0) continue;
                if (held == key) { was = true; continue; }
                kept.Add(held);
            }

            if (!was) kept.Add(key);

            Expanded = string.Join(ExpandedSep.ToString(), kept.ToArray());
        }

        protected bool IsOpen(object key)
        {
            string k = Convert.ToString(key);
            if (k.Length == 0) return false;

            foreach (string held in Expanded.Split(ExpandedSep))
                if (held == k) return true;

            return false;
        }

        protected string CaretClass(object key)
        {
            return IsOpen(key) ? "vs-caret open" : "vs-caret";
        }

        protected string RowClass(object key)
        {
            return IsOpen(key) ? "vs-prow open" : "vs-prow";
        }

        /// <summary>
        /// The student's name, written once above its own run of rows. When the
        /// row above belongs to the same student the cell is left empty, which
        /// is what makes two providers read as one person's work rather than as
        /// two people who happen to share a name.
        ///
        /// A sort that scatters a student's rows turns every run into one row,
        /// so every row gets its name back without this having to know that a
        /// sort happened.
        /// </summary>
        protected string StudentCell(object studentId, object name)
        {
            string id = Convert.ToString(studentId);

            if (id.Length > 0 && id == _lastStudent) return string.Empty;
            _lastStudent = id;

            return "<b>" + Server.HtmlEncode(Convert.ToString(name)) + "</b>";
        }

        /// <summary>
        /// The student the row above belonged to. A field rather than a look
        /// back into the data source: a Repeater binds its rows in order, so
        /// "the one before this" is simply the last one asked about.
        /// </summary>
        private string _lastStudent;

        /// <summary>
        /// The products of an opened row, as rows of the same table. Emitted
        /// whole rather than templated because a nested Repeater cannot break
        /// out of its parent's cell to line up with these columns.
        ///
        /// Weekly and monthly are left as a dash. They are counted from the
        /// history log per provider, and splitting them per product needs a proc
        /// that does not exist; a number that looked right and was not would be
        /// worse than the dash. The three beside them are per product and exact.
        /// </summary>
        protected string ProductRows(object key, object names, object all, object done, object pending)
        {
            if (!IsOpen(key)) return string.Empty;

            string raw = Convert.ToString(names);
            if (raw.Trim().Length == 0)
                return "<tr class=\"vs-subrow\"><td></td><td></td><td colspan=\"6\" class=\"vs-subnone\">"
                     + "No products held under this provider.</td></tr>";

            string[] nm = raw.Split('|');
            string[] na = Convert.ToString(all).Split('|');
            string[] nc = Convert.ToString(done).Split('|');
            string[] np = Convert.ToString(pending).Split('|');

            var sb = new StringBuilder();
            for (int i = 0; i < nm.Length; i++)
            {
                string name = nm[i].Trim();
                if (name.Length == 0) continue;

                sb.Append("<tr class=\"vs-subrow\"><td></td><td></td><td>")
                  .Append("<span class=\"vs-prodname\"><span class=\"dot\"></span>")
                  .Append(Server.HtmlEncode(name)).Append("</span></td>")
                  .Append(Cell(Slot(na, i), string.Empty))
                  .Append(Cell(Slot(nc, i), " vs-done"))
                  .Append(Cell(Slot(np, i), " vs-todo"))
                  .Append("<td class=\"c vs-subdash\" title=\"Weekly is counted per provider\">&mdash;</td>")
                  .Append("<td class=\"c vs-subdash\" title=\"Monthly is counted per provider\">&mdash;</td>")
                  .Append("</tr>");
            }

            return sb.ToString();
        }

        private static string Slot(string[] parts, int i)
        {
            return (parts != null && i < parts.Length) ? parts[i].Trim() : string.Empty;
        }

        private string Cell(string value, string tone)
        {
            return "<td class=\"c\"><span class=\"vs-subcount vs-num" + tone + "\">"
                 + Server.HtmlEncode(value.Length == 0 ? "0" : value) + "</span></td>";
        }

        protected string ProductLabel(object count)
        {
            int n;
            if (!int.TryParse(Convert.ToString(count), out n)) return string.Empty;
            return n.ToString() + (n == 1 ? " product" : " products");
        }

        #endregion

        /// <summary>
        /// The provider's badge, the same one the Voucher Status tables carry.
        /// Helpers/ProviderBrand.cs picks the logo or falls back to initials.
        /// </summary>
        protected string ProviderTile(object providerId, object name)
        {
            return ProviderBrand.Tile(providerId, name, "logo");
        }
    }
}
