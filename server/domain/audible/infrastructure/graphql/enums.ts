import { builder } from '~/domain/shared/graphql/builder'

export const AudibleMarketplaceEnum = builder.enumType('AudibleMarketplace', {
  description:
    'The Amazon store an Audible account was opened on.\n\n' +
    'It decides which domain the sign-in page and the API live on, so a ' +
    'connection made on the wrong one simply finds an empty library. The reader ' +
    'picks it once, when connecting.',
  values: {
    FR: { value: 'fr', description: 'audible.fr' },
    COM: { value: 'com', description: 'audible.com (United States)' },
    CO_UK: { value: 'co.uk', description: 'audible.co.uk' },
    DE: { value: 'de', description: 'audible.de' },
    IT: { value: 'it', description: 'audible.it' },
    ES: { value: 'es', description: 'audible.es' },
    CA: { value: 'ca', description: 'audible.ca' },
    COM_AU: { value: 'com.au', description: 'audible.com.au' },
    IN: { value: 'in', description: 'audible.in' },
    CO_JP: { value: 'co.jp', description: 'audible.co.jp' },
  } as const,
})

export const AudibleDrmEnum = builder.enumType('AudibleDrm', {
  description:
    'The DRM a title is licensed in: the one the device plays natively. The ' +
    'stream is never decrypted outside it.',
  values: {
    FAIRPLAY: {
      value: 'fairplay',
      description: "Apple's: an HLS stream, its keys traded with `audibleFairPlayKey`.",
    },
    WIDEVINE: {
      value: 'widevine',
      description: "Android's: a DASH manifest, its keys traded with `audibleWidevineKey`.",
    },
  } as const,
})
