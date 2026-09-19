import { generateDomainInstrumentation } from './server/system/sentry/generate-domain-instrumentation'

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
    attachmentsBucket: '',
    // Seals the Amazon device credentials an Audible connection is made of, so a
    // Firestore export does not hand out standing access to readers' accounts.
    audibleKey: '',
    // Dev only: the origin the local object store points its URLs at, so the
    // simulator downloads an attachment from the same server it queried.
    publicBaseUrl: 'http://127.0.0.1:3000',
  },
})
