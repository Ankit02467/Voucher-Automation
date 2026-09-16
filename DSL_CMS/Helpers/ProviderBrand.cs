using System;
using System.Text;
using System.Web;
using System.Web.Hosting;

namespace DSL_CMS.Helpers
{
    /// <summary>
    /// The coloured tile a provider is drawn as. Both the sidebar in MasterPage
    /// and the table on Voucher Status show it; keeping one copy is what stops
    /// the two from disagreeing the first time a logo file is dropped in.
    /// </summary>
    public static class ProviderBrand
    {
        /// <summary>
        /// Tile colour, taken straight off the provider id.
        ///
        /// Hashing the name looked cleverer but collided - ETS and LanguageCERT
        /// both landed on green. Walking the palette by id cannot collide until
        /// there are more providers than colours, and each provider keeps its
        /// colour for good.
        /// </summary>
        private static readonly string[] Palette =
        {
            "#ff9900",  // orange
            "#0f6cbd",  // blue
            "#7a2ff2",  // violet
            "#e0392b",  // red
            "#0e9f6e",  // green
            "#d946ef",  // magenta
            "#0891b2",  // teal
            "#b45309"   // amber
        };

        private static readonly string[] LogoExtensions = { ".png", ".svg", ".jpg", ".jpeg", ".webp" };

        /// <summary>
        /// Letters for the tile when there is no logo file. Capitals carried in
        /// the name work better than the first few characters: LanguageCERT
        /// gives "LC", not "LAN".
        /// </summary>
        public static string Initials(object name)
        {
            string text = Convert.ToString(name).Trim();
            if (text.Length == 0) return "?";

            // A name that is already an acronym is shown whole: AWS, PTE, ETS.
            bool acronym = true;
            foreach (char c in text)
                if (char.IsLetter(c) && !char.IsUpper(c)) { acronym = false; break; }

            if (acronym)
                return text.Substring(0, Math.Min(3, text.Length)).ToUpperInvariant();

            // Otherwise two capitals: LanguageCERT gives LC, not LCE.
            var caps = new StringBuilder();
            foreach (char c in text)
            {
                if (char.IsUpper(c)) caps.Append(c);
                if (caps.Length == 2) break;
            }

            if (caps.Length == 2) return caps.ToString();

            return text.Substring(0, Math.Min(2, text.Length)).ToUpperInvariant();
        }

        public static string LogoStyle(object providerId)
        {
            int id;
            if (!int.TryParse(Convert.ToString(providerId), out id) || id < 1) id = 1;

            return "background: " + Palette[(id - 1) % Palette.Length] + ";";
        }

        /// <summary>
        /// A logo from ~/assets/img/providers if one is there, otherwise blank.
        ///
        /// Expected name: the provider name lowercased with anything that is not
        /// a letter or digit removed - AWS becomes aws.png, LanguageCERT becomes
        /// languagecert.png. png, svg, jpg and webp are all looked for.
        /// </summary>
        public static string LogoUrl(object name)
        {
            string slug = Slug(Convert.ToString(name));
            if (slug.Length == 0) return string.Empty;

            // Server.MapPath plus a disk hit per provider per render is wasteful
            // when the answer cannot change inside one request - and the sidebar
            // now asks for every provider on every page.
            string key = "ProviderLogo:" + slug;
            HttpContext ctx = HttpContext.Current;
            if (ctx != null && ctx.Items.Contains(key))
                return Convert.ToString(ctx.Items[key]);

            string found = string.Empty;
            foreach (string ext in LogoExtensions)
            {
                string rel = "~/assets/img/providers/" + slug + ext;
                try
                {
                    string path = HostingEnvironment.MapPath(rel);
                    if (path != null && System.IO.File.Exists(path))
                    {
                        found = VirtualPathUtility.ToAbsolute(rel);
                        break;
                    }
                }
                catch { }
            }

            if (ctx != null) ctx.Items[key] = found;
            return found;
        }

        /// <summary>
        /// Where a provider's logo belongs, whether or not anything is there yet.
        /// The name lowercased with anything that is not a letter or digit taken
        /// out, so CISCO is ~/assets/img/providers/cisco.svg.
        /// </summary>
        public static string ExpectedLogoUrl(object name)
        {
            return ExpectedLogoUrl(name, ".svg");
        }

        public static string ExpectedLogoUrl(object name, string extension)
        {
            string slug = Slug(Convert.ToString(name));
            if (slug.Length == 0) return string.Empty;

            return VirtualPathUtility.ToAbsolute("~/assets/img/providers/" + slug + extension);
        }

        /// <summary>
        /// The finished tile. <paramref name="cssClass"/> lets the sidebar ask
        /// for its smaller variant without a second copy of this markup.
        ///
        /// A provider whose file is already in the folder is drawn exactly as it
        /// always was. A provider with no file **still carries the path its logo
        /// would be at**, so dropping `cisco.svg` into assets/img/providers is the
        /// whole of giving CISCO a logo - no code change, and nobody has to work
        /// out what to call the file: it is in the page, in front of them.
        ///
        /// The image is hidden until it loads (`vdLogoOn`, on MasterPage). If
        /// nothing is there it is tried once more as .png and then taken out
        /// (`vdLogoOff`), leaving the coloured initials that were there before -
        /// so a provider without a logo looks exactly as it looks today, and a
        /// missing file never leaves a broken-image mark in the table.
        ///
        /// It costs a 404 per logo-less provider per page. Worth it: the
        /// alternative is a code change, or a README, every time a provider is
        /// added.
        /// </summary>
        public static string Tile(object providerId, object name, string cssClass)
        {
            string logo = LogoUrl(name);

            if (logo.Length > 0)
            {
                return "<span class=\"" + cssClass + " has-img\"><img src=\"" + HttpUtility.HtmlEncode(logo)
                     + "\" alt=\"" + HttpUtility.HtmlEncode(Convert.ToString(name)) + "\" /></span>";
            }

            string tile = "<span class=\"" + cssClass + "\" style=\"" + LogoStyle(providerId) + "\">";
            string initials = HttpUtility.HtmlEncode(Initials(name));
            string expected = ExpectedLogoUrl(name);

            // A name with no letters or digits in it has no file name to offer.
            if (expected.Length == 0) return tile + initials + "</span>";

            return tile
                 + "<img src=\"" + HttpUtility.HtmlEncode(expected)
                 + "\" alt=\"" + HttpUtility.HtmlEncode(Convert.ToString(name))
                 + "\" data-alt=\"" + HttpUtility.HtmlEncode(ExpectedLogoUrl(name, ".png"))
                 + "\" onload=\"vdLogoOn(this)\" onerror=\"vdLogoOff(this)\" />"
                 + "<i>" + initials + "</i></span>";
        }

        private static string Slug(string text)
        {
            var sb = new StringBuilder();
            foreach (char c in text ?? string.Empty)
                if (char.IsLetterOrDigit(c)) sb.Append(char.ToLowerInvariant(c));
            return sb.ToString();
        }
    }
}
