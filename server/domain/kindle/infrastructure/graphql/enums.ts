import { builder } from '~/domain/shared/graphql/builder'

export const KindleMarketplaceEnum = builder.enumType('KindleMarketplace', {
  description:
    'The Amazon store a Kindle library lives on.\n\n' +
    'It decides which domain the sign-in page and the library live on, so a ' +
    'connection made on the wrong one simply finds an empty library. The reader ' +
    'picks it once, when connecting. Its own enum rather than ' +
    '`AudibleMarketplace`: the two connections are independent, and a reader ' +
    'may buy ebooks and audiobooks on different stores.',
  values: {
    FR: { value: 'fr', description: 'amazon.fr' },
    COM: { value: 'com', description: 'amazon.com (United States)' },
    CO_UK: { value: 'co.uk', description: 'amazon.co.uk' },
    DE: { value: 'de', description: 'amazon.de' },
    IT: { value: 'it', description: 'amazon.it' },
    ES: { value: 'es', description: 'amazon.es' },
    CA: { value: 'ca', description: 'amazon.ca' },
    COM_AU: { value: 'com.au', description: 'amazon.com.au' },
    IN: { value: 'in', description: 'amazon.in' },
    CO_JP: { value: 'co.jp', description: 'amazon.co.jp' },
  } as const,
})
