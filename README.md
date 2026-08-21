# BlueHealth public assets

Images, fonts, logos, icons, videos and 3D models used by the apps. Everything
here is **public** and world-readable — never add patient data, exports, or
anything access-controlled.

Served at **https://assets.bluehealth.co** (Cloudflare R2, bucket `assets`,
provisioned in `bluehealth-infra`). Consumed through `@common/assets`
(`getAssetsUrl("presentation/heart.glb")`), never by a hardcoded URL.

## Filenames are immutable

`assets.bluehealth.co` is cached for **a year at the edge and a year in the
browser**, so the consultation kiosk never waits on a revalidation round trip
while a patient watches a multi-megabyte organ model load.

The price is that **you cannot republish different bytes under a name that is
already live**. A cache purge clears Cloudflare, but nothing can evict a copy a
browser already holds — that kiosk keeps serving the old file until someone
clears its cache by hand.

So, to change an asset:

1. Add it under a **new filename**. This repo already versions by dimension
   (`img/model-front-f-presentation-@2134x2160.webp`); a suffix works too
   (`-v2`, a date, the new size).
2. Point the app code at the new path (`common/assets/types-paths.ts` is
   generated from this repo, so run the assets codegen in `bluehealth`).
3. Leave the old file in place until nothing references it — including shipped
   native builds, which have asset URLs baked in.

Deleting a file from git does **not** remove it from the bucket: the sync runs
without `--delete` for exactly that reason.

## The rule is enforced

Two guards, because getting this wrong is not undoable:

- **CI** — [`.github/workflows/immutability.yml`](.github/workflows/immutability.yml)
  fails any PR that gives different bytes to a filename that is already tracked,
  and the sync workflow repeats the check before uploading so a push straight to
  `main` cannot slip past. Adding, renaming and deleting all pass. If a path has
  genuinely never been deployed or fetched, label the PR `allow-overwrite` to
  bypass.
- **Locally** (optional, faster) — enable the same check as a pre-commit hook:

  ```bash
  git config core.hooksPath .githooks
  ```

## `draco/`

The Draco decoder that `DRACOLoader` fetches at runtime, so compressed models do
not depend on Google's CDN. The folder is named after the three.js release whose
`examples/jsm/libs/draco/gltf/` build it holds — bumping three means copying the
files into a **new** folder and updating `DRACO_DECODER_PATH` in the app repo,
never replacing these.

## Publishing

Push to `main`. [`.github/workflows/sync-r2.yml`](.github/workflows/sync-r2.yml)
mirrors the repo into the bucket.

Comparison is by size, so re-running never fixes an object's *metadata* — a
wrong `Content-Type` on an already-uploaded key needs an explicit
`aws s3 cp s3://assets/<key> s3://assets/<key> --metadata-directive REPLACE
--content-type <type> --cache-control "public, max-age=31536000, immutable"`.

`.glb` and `.lottie` are uploaded in their own passes with an explicit
`Content-Type`, because the AWS CLI guesses those wrong and `GLTFLoader` refuses
a model served as `application/octet-stream`.

Required repository secrets: `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY` — a
bucket-scoped R2 API token with Object Read & Write, from the Cloudflare
dashboard (R2 → Manage API Tokens).

The workflow does not purge the CDN and needs no Cloudflare token: added paths
have nothing cached, changed paths are not allowed, and the cache rule is set to
never cache error responses.
