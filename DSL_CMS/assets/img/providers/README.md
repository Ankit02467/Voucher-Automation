# Provider logos

Drop a logo here and Voucher Status, Student-wise Performance and the sidebar pick
it up on the next page load. No code change, no restart, no list to register it in.

**The page tells you the file name.** Every provider tile carries the path its logo
would be at, whether or not anything is there yet — a provider added today is drawn
as `<img src="/assets/img/providers/cisco.svg" alt="CISCO">` with its coloured
initials behind it. So the file name is never something to look up: open the page,
look at the tile, put a file of that name here.

**Put it in the repository, in this folder, on `uat`.** The project includes the
whole folder (`assets\img\providers\*.*` in `DSL_CMS.csproj`), so the pipeline
publishes whatever is here. A file copied straight onto the server shows at once,
but the next deploy deletes it: its robocopy `/MIR` removes anything the build
did not produce.

Name the file after the provider, lowercased, with anything that is not a letter
or digit removed:

| Provider | File |
|---|---|
| AWS | `aws.svg` |
| Microsoft | `microsoft.svg` |
| PTE | `pte.svg` |
| ETS | `ets.svg` |
| LanguageCERT | `languagecert.svg` |
| CompTIA | `comptia.svg` or `comptia.png` |
| Peoplecert | `peoplecert.svg` or `peoplecert.png` |
| CISCO | `cisco.svg` or `cisco.png` |

`.png`, `.svg`, `.jpg`, `.jpeg` and `.webp` all work; they are looked for in that
order. Prefer `.svg` or `.png`: IIS serves both out of the box, and `.webp` needs a
MIME type the server may not have.

**A provider with no file keeps the coloured initials**, exactly as before. The
tile asks for `<name>.svg` first and `<name>.png` second; if neither is there the
image is taken back out of the page, so a missing logo is never a broken-image
mark and never a hole in the table. Drop either file in and it shows on the next
page load — the page then draws it the way it draws AWS, from the file itself
rather than from the guess.

The tile is 34px square in the Voucher Status table and 23px in the sidebar, and
the image is contained inside it on a white background, so a wide or tall mark will
not be cropped or stretched. Square-ish artwork with a
little padding of its own looks best. Transparent PNG or SVG is ideal.

These are third party trademarks, so the files have to come from you or from
whatever the brands' own guidelines allow.
