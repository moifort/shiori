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
      timeoutSeconds: 60,
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
    // Dev only: the origin the local object store points its URLs at, so the
    // simulator downloads an attachment from the same server it queried.
    publicBaseUrl: 'http://127.0.0.1:3000',
  },
})
