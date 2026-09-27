import { describe, expect, test } from 'bun:test'
import { buildSchema } from 'graphql'
import { coordinatesUsedBy, deprecatedElementsOf } from './usage'

const schema = buildSchema(`
  type Query {
    library(rated: Boolean @deprecated(reason: "gone"), favorite: Boolean): [Book!]!
    book(id: ID!): Book
  }
  type Mutation { addBook(input: BookInput!): Book! }
  type Book {
    id: ID!
    title: String!
    pages: Int @deprecated(reason: "gone")
    series: Series
  }
  type Series { id: ID! pages: Int }
  input BookInput { title: String! legacy: String @deprecated(reason: "gone") }
  enum Status { READ TO_READ @deprecated(reason: "gone") }
`)

describe('the deprecated elements of a schema', () => {
  test('are listed by coordinate, and only fields and arguments can be traced', () => {
    expect(deprecatedElementsOf(schema)).toEqual([
      { coordinate: 'Query.library(rated:)', traceable: true },
      { coordinate: 'Book.pages', traceable: true },
      { coordinate: 'BookInput.legacy', traceable: false },
      { coordinate: 'Status.TO_READ', traceable: false },
    ])
  })
})

describe('the coordinates an operation uses', () => {
  test('match the exact type, so two types sharing a field name are not confused', () => {
    const used = coordinatesUsedBy(schema, ['query { book(id: "1") { series { pages } } }'])

    expect(used.has('Series.pages')).toBe(true)
    expect(used.has('Book.pages')).toBe(false)
  })

  test('include the arguments an operation passes', () => {
    const used = coordinatesUsedBy(schema, ['query($r: Boolean) { library(rated: $r) { id } }'])

    expect(used.has('Query.library(rated:)')).toBe(true)
    expect(used.has('Query.library(favorite:)')).toBe(false)
  })

  // Apollo iOS lets a fragment live in one file and the query that spreads it in another.
  test('follow a fragment defined in another file', () => {
    const used = coordinatesUsedBy(schema, [
      'query { library { ...Row } }',
      'fragment Row on Book { pages }',
    ])

    expect(used.has('Book.pages')).toBe(true)
  })

  // An old operation may name a field the schema has since lost: it is skipped, not fatal.
  test('ignore what the schema no longer knows', () => {
    const used = coordinatesUsedBy(schema, ['query { book(id: "1") { vanished title } }'])

    expect(used.has('Book.title')).toBe(true)
  })
})
