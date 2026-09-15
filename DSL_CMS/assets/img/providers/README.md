# Provider logos

Drop a logo here and Voucher Status and the sidebar pick it up on the next page
load. No code change, no restart, no list to register it in.

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

The page then draws `<img src="/assets/img/providers/comptia.svg" alt="CompTIA">`,
the same as for every other provider with a file here.

`.png`, `.svg`, `.jpg`, `.jpeg` and `.webp` all work; they are looked for in that
order. Prefer `.svg` or `.png`: IIS serves both out of the box, and `.webp` needs a
MIME type the server may not have. A provider with no file here keeps the coloured initials tile, so a
missing logo never leaves a hole in the table.

The tile is 34px square in the Voucher Status table and 23px in the sidebar, and
the image is contained inside it on a white background, so a wide or tall mark will
not be cropped or stretched. Square-ish artwork with a
little padding of its own looks best. Transparent PNG or SVG is ideal.

These are third party trademarks, so the files have to come from you or from
whatever the brands' own guidelines allow.
