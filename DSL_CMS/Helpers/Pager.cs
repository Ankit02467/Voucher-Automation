using System;
using System.Collections.Generic;
using System.Data;

namespace DSL_CMS.Helpers
{
    /// <summary>
    /// Client side paging for the grids. The stored procedures return the
    /// full result set (a few hundred rows at most), so the page slice is
    /// taken here rather than adding OFFSET/FETCH to every proc.
    /// </summary>
    public static class Pager
    {
        public const int DefaultPageSize = 10;

        /// <summary>Total number of pages for a row count (never less than 1).</summary>
        public static int PageCount(int rowCount, int pageSize)
        {
            if (pageSize <= 0) return 1;
            int pages = (rowCount + pageSize - 1) / pageSize;
            return pages < 1 ? 1 : pages;
        }

        /// <summary>Returns just the rows belonging to <paramref name="pageIndex"/> (0 based).</summary>
        public static DataTable Slice(DataTable source, int pageIndex, int pageSize)
        {
            if (source == null) return null;
            if (pageSize <= 0) return source;

            DataTable page = source.Clone();
            int start = pageIndex * pageSize;

            for (int i = start; i < start + pageSize && i < source.Rows.Count; i++)
                page.ImportRow(source.Rows[i]);

            return page;
        }

        /// <summary>
        /// Page numbers to render, windowed around the current page so the
        /// pager stays short when there are many pages. -1 means an ellipsis.
        /// </summary>
        public static List<PageLink> Links(int pageCount, int currentIndex, int window = 2)
        {
            var links = new List<PageLink>();
            if (pageCount <= 1) return links;

            int first = Math.Max(0, currentIndex - window);
            int last = Math.Min(pageCount - 1, currentIndex + window);

            if (first > 0)
            {
                links.Add(new PageLink(0, currentIndex));
                if (first > 1) links.Add(PageLink.Ellipsis);
            }

            for (int i = first; i <= last; i++)
                links.Add(new PageLink(i, currentIndex));

            if (last < pageCount - 1)
            {
                if (last < pageCount - 2) links.Add(PageLink.Ellipsis);
                links.Add(new PageLink(pageCount - 1, currentIndex));
            }

            return links;
        }

        public class PageLink
        {
            public static readonly PageLink Ellipsis = new PageLink(-1, -2);

            public PageLink(int index, int currentIndex)
            {
                Index = index;
                IsEllipsis = index < 0;
                IsCurrent = !IsEllipsis && index == currentIndex;
            }

            public int Index { get; private set; }
            public bool IsCurrent { get; private set; }
            public bool IsEllipsis { get; private set; }

            /// <summary>1 based label shown on the button.</summary>
            public string Label { get { return IsEllipsis ? "..." : (Index + 1).ToString(); } }

            public string CssClass
            {
                get
                {
                    if (IsEllipsis) return "pg dots";
                    return IsCurrent ? "pg on" : "pg";
                }
            }
        }
    }
}
