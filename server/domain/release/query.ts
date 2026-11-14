import * as repository from '~/domain/release/infrastructure/repository'
import type { Release } from '~/domain/release/types'

export namespace ReleaseQuery {
  /** The releases under these keys, in one getAll, keyed by theirs. */
  export const byKeys = async (keys: readonly string[]): Promise<Map<string, Release>> =>
    new Map((await repository.findReleases(keys)).map((release) => [release.key, release]))
}
