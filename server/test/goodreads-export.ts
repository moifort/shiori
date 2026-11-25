/** A Goodreads library export as the site writes it in 2026: every column of
 *  the current format, ISBNs as spreadsheet formulas, dates with slashes, a
 *  review in HTML, a custom "dnf" shelf. Test data only. */
const HEADER =
  'Book Id,Title,Author,Author l-f,Additional Authors,ISBN,ISBN13,My Rating,Average Rating,' +
  'Publisher,Binding,Number of Pages,Year Published,Original Publication Year,Date Read,' +
  'Date Added,Bookshelves,Bookshelves with positions,Exclusive Shelf,My Review,Spoiler,' +
  'Private Notes,Read Count,Owned Copies'

const ROWS = [
  '7235533,"The Way of Kings (The Stormlight Archive, #1)",Brandon Sanderson,"Sanderson, Brandon",,' +
    '="0765326353",="9780765326355",5,4.65,Tor Books,Hardcover,1007,2010,2010,2024/05/12,' +
    '2024/04/01,,,read,"Loved it.<br/><br/>Kaladin!",,,1,0',
  '12067,Le Nom du vent,Patrick Rothfuss,"Rothfuss, Patrick",,="2352942578",="9782352942573",4,' +
    '4.52,Bragelonne,Paperback,826,2009,2007,2023/01/02,2022/12/20,,,read,,,,1,0',
  '36236124,Hypérion,Dan Simmons,"Simmons, Dan",,="",="",0,4.25,Pocket,Kindle Edition,,2014,' +
    '1989,,2025/10/01,,,currently-reading,,,,0,0',
  '41886271,Fondation,Isaac Asimov,"Asimov, Isaac",,="2070360539",="9782070360536",0,4.17,' +
    'Folio,Mass Market Paperback,416,2009,1951,,2025/11/02,,,to-read,,,,0,0',
  '29579,"Le Problème à trois corps (Remembrance of Earth\'s Past, #1)",Liu Cixin,"Cixin, Liu",,' +
    '="",="",2,4.07,Actes Sud,Paperback,500,2016,2008,2025/02/01,2025/01/15,dnf,dnf (#1),read,' +
    ',,,1,0',
  '7235533,"The Way of Kings (The Stormlight Archive, #1)",Brandon Sanderson,"Sanderson, Brandon",,' +
    '="",="",0,4.65,Tor,Kindle Edition,,2010,2010,,2024/04/02,,,to-read,,,,0,0',
]

export const GOODREADS_EXPORT = [HEADER, ...ROWS].join('\n')
