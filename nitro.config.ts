import { generateDomainInstrumentation } from './server/system/sentry/generate-domain-instrumentation'

/** The packages a production build keeps as files rather than bundling in. */
const BUNDLED_AS_FILES =
  /firebase-functions|firebase-admin|@google-cloud\/|google-auth-library|google-gax|gaxios|gcp-metadata|gtoken|@grpc\/|protobufjs|proto3-json-serializer|@sentry\//

export default defineNitroConfig({
  compatibilityDate: '2026-09-14',
  experimental: { asyncContext: true },
  srcDir: 'server',
  ignore: ['**/*.test.ts'],
  preset: 'firebase',
  firebase: {
    gen: 2,
    nodeVersion: '22',
    httpsOptions: {
      region: 'europe-west3',
      memory: '512MiB',
      // A scan is three grounded Gemini calls with thinking enabled, and a cold
      // one was measured at 55s end to end against the real API — under
      // Vinarium's 60s ceiling by five seconds, which is no margin at all. The
      // request that tips over does not degrade, it 504s after the models have
      // already been paid for.
      //
      // Only `firebase deploy` reads this block. The deploy goes through
      // Terraform, so the ceiling that actually applies is `timeout_seconds` in
      // infra/function.tf; the two are kept equal so that neither misleads.
      timeoutSeconds: 180,
      concurrency: 80,
    },
  },
  // Rollup minifies the whole backend into one file, so an unmapped stack trace
  // points at a column of index.mjs. The maps are uploaded to Sentry at deploy
  // time and stay out of the deployed bundle.
  sourceMap: true,
  // A cold start spent 3.6 s of its 4.3 s loading dependencies before the first
  // line of our bundle (the `[boot]` probes, 89 instances, 2026-10-30/11-01): the
  // firebase preset leaves them as 3,199 files in node_modules, and Cloud Run
  // pays every one of them. Bundling them in cut the load by 41 % on a Mac
  // (710 → 418 ms, Node 22), which is what Nitro 3 does by default. The
  // Firebase and gRPC stack stays on disk: google-gax reads its .proto files
  // through `__dirname`, which has no meaning inside an ES module, and
  // firebase-admin requires @google-cloud/firestore by deep path. Sentry stays
  // whole: its injection package registers a module hook it locates by its own
  // package name (bundled in, it resolves from `/_entry.js`, fails, and the
  // outgoing HTTP spans silently stop being recorded), and keeping only that
  // package out would load a second copy of @sentry/core beside the bundled one.
  externals: {
    external: [BUNDLED_AS_FILES],
    inline: [(id) => !BUNDLED_AS_FILES.test(id)],
  },
  // jws does `require('stream')` and expects the Stream constructor, not the
  // module namespace rollup hands a bare require of a builtin.
  commonJS: { requireReturnsDefault: 'preferred' },
  rollupConfig: {
    treeshake: {
      moduleSideEffects: (id) => id.includes('/graphql/') || id.includes('node_modules'),
    },
  },
  virtual: {
    '#domain-instrumentation': generateDomainInstrumentation,
  },
  runtimeConfig: {
    googleApiKey: '',
    adminToken: '',
    sentryDsn: '',
    // Baked in at build time by the deploy workflow (the git SHA), so Sentry can
    // tell which deploy an error comes from and pick the matching source maps.
    sentryRelease: process.env.SENTRY_RELEASE ?? '',
    devUserId: '',
    scanStub: '',
    appleEnvironment: '',
    premiumUserIds: '',
    ascIssuerId: '',
    ascKeyId: '',
    ascPrivateKey: '',
    ascVendorNumber: '',
    gcpBillingTable: '',
    // The project the function runs in, set by Terraform: what the billing
    // export's rows are filtered on, and where the BigQuery job runs.
    firebaseProjectId: '',
    // The GA4 property the app reports to, for the admin screen's sessions.
    ga4PropertyId: '',
    attachmentsBucket: '',
    // The SHA-256 fingerprints the Android app is signed with, comma-separated, for App Links.
    androidCertSha256: '',
    // Seals the Amazon device credentials an Audible connection is made of, so a
    // Firestore export does not hand out standing access to readers' accounts.
    audibleKey: '',
    // The same, for the Kindle device credentials, under a key of its own.
    kindleKey: '',
    // Claude's API key, for the month's discoveries in Découvrir. Blank and the
    // line is simply absent; nothing else reads it.
    anthropicApiKey: '',
    // Push notifications through APNs: a key with the APNs service enabled, its
    // id, and the team that owns it. Any of them blank and the alerts are only
    // logged, never sent.
    apnsKeyId: '',
    apnsPrivateKey: '',
    apnsTeamId: '',
    // Dev only: the origin the local object store points its URLs at, so the
    // simulator downloads an attachment from the same server it queried.
    publicBaseUrl: 'http://127.0.0.1:3000',
  },
})
