import { describe, expect, test } from 'bun:test'
import { titleWithoutSaga } from '~/domain/shared/saga-title'

describe('titleWithoutSaga', () => {
  test('drops the saga and the volume written in front of the title', () => {
    expect(
      titleWithoutSaga('Crescent City, Tome 1 : Maison de la Terre et du Sang', 'Crescent City'),
    ).toBe('Maison de la Terre et du Sang')
    expect(
      titleWithoutSaga(
        "La Trilogie Baryonique - Tome 1 : La Tragédie de l'Orque",
        'La Trilogie Baryonique',
      ),
    ).toBe("La Tragédie de l'Orque")
    expect(titleWithoutSaga('Le Sorceleur T.4 : Le Temps du mépris', 'Le Sorceleur')).toBe(
      'Le Temps du mépris',
    )
    expect(
      titleWithoutSaga('Crescent City 2 - Maison du Ciel et du Souffle', 'Crescent City'),
    ).toBe('Maison du Ciel et du Souffle')
    expect(titleWithoutSaga('Royaume de Tobald, Livre II : Ex-Pharaon', 'Royaume de Tobald')).toBe(
      'Ex-Pharaon',
    )
  })

  test('drops a volume written after the title', () => {
    expect(titleWithoutSaga('System Universe - Torith - Tome 2', 'System Universe')).toBe('Torith')
    expect(titleWithoutSaga('Le Nom du vent, tome 1', 'Chronique du tueur de roi')).toBe(
      'Le Nom du vent',
    )
    expect(
      titleWithoutSaga(
        'Le Nom du vent (Chronique du tueur de roi, tome 1)',
        'Chronique du tueur de roi',
      ),
    ).toBe('Le Nom du vent')
    expect(titleWithoutSaga('Tome 3 : Le Prince', 'Le Roi')).toBe('Le Prince')
  })

  test('a volume with no title of its own goes by its saga', () => {
    expect(titleWithoutSaga('Old Boy, tome 2', 'Old Boy')).toBe('Old Boy')
    expect(titleWithoutSaga('Old Boy 5', 'Old Boy')).toBe('Old Boy')
    expect(titleWithoutSaga('One Piece #12', 'One Piece')).toBe('One Piece')
    expect(titleWithoutSaga('Tome 4', 'Old Boy')).toBe('Old Boy')
  })

  test('keeps a title that names no volume', () => {
    expect(titleWithoutSaga('Old Boy', 'Old Boy')).toBe('Old Boy')
    expect(
      titleWithoutSaga("La Légende des Firemane - L'intégrale", 'La Légende des Firemane'),
    ).toBe("La Légende des Firemane - L'intégrale")
    expect(titleWithoutSaga('Dune Messiah', 'Dune')).toBe('Dune Messiah')
    expect(titleWithoutSaga('Le Nom du Vent - Seconde partie', 'Chronique du Tueur de Roi')).toBe(
      'Le Nom du Vent - Seconde partie',
    )
    expect(titleWithoutSaga('Le Mort 2', 'Saga')).toBe('Le Mort 2')
    expect(titleWithoutSaga('Blade Runner 2049', 'Blade Runner')).toBe('Blade Runner 2049')
  })

  test('keeps the title of a book outside any saga', () => {
    expect(titleWithoutSaga('Fourth Wing, Tome 1', undefined)).toBe('Fourth Wing, Tome 1')
  })
})
