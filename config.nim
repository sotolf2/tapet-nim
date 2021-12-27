import 
  std/db_sqlite,
  std/parsecfg,
  std/strutils,
  std/uri

type Tapet* = object
  favoritesFolder*: string
  downloadsFolder*: string
  previousFolder*: string
  previousKeep*: int
  wallpaperSetter*: string
  history*: int
  interval*: int
  downloadEvery*: int

type Wallhaven* = object
  downloadNum*: int
  tags*: string

type Config* = object
  tapet*: Tapet
  wallhaven*: Wallhaven

proc parseConfig*(filePath: string): Config =
  let dict = loadConfig(filePath)
  var tapet: Tapet
  tapet.favoritesFolder = dict.getSectionValue("tapet", "favorites_folder")
  tapet.downloadsFolder = dict.getSectionValue("tapet", "downloads_folder")
  tapet.previousFolder = dict.getSectionValue("tapet", "previous_folder")
  tapet.previousKeep = dict.getSectionValue("tapet", "previous_keep").parseInt
  tapet.wallpaperSetter = dict.getSectionValue("tapet", "wallpaper_setter")
  tapet.history = dict.getSectionValue("tapet", "history").parseInt
  tapet.interval = dict.getSectionValue("tapet", "interval").parseInt
  tapet.downloadEvery = dict.getSectionValue("tapet", "download_every").parseInt

  var wallhaven: Wallhaven
  wallhaven.downloadNum = dict.getSectionValue("wallhaven", "download_number").parseInt
  wallhaven.tags = dict.getSectionValue("wallhaven", "tags")

  result.tapet = tapet
  result.wallhaven = wallhaven

type State* = object
  currentWallpaper*: string
  isFavorite*: bool
  isDownloaded*: bool

proc getState*(db: DbConn): State =
  let stateStrings = db.getRow(sql"""select * from state""")
  if stateStrings == @["", "", ""]:
    result.currentWallpaper = ""
    result.isFavorite = false
    result.isDownloaded = false
  else:
    result.currentWallpaper = stateStrings[0]
    result.isFavorite = stateStrings[1].parseBool
    result.isDownloaded = stateStrings[2].parseBool

proc setState*(db: DbConn, state: State) =
  var favoriteString: string
  var downlodedString: string
  if state.isFavorite:
    favoriteString = "1"
  else:
    favoriteString = "0"
  if state.isDownloaded:
    downlodedString = "1"
  else:
    downlodedString = "0"
  db.exec(sql"""delete from state where current_wallpaper is not null""")
  db.exec(sql"""insert into state(current_wallpaper, is_favourite, is_downloaded) values(?, ?, ?)""", state.currentWallpaper, favoriteString, downlodedString)


proc ensureState*(db: DbConn) =
  # makes sure that the needed tables are in the database, 
  # if they are not they are created
  
  db.exec(sql"""create table if not exists state (
    current_wallpaper text
    , is_favourite boolean
    , is_downloaded boolean);""")

  db.exec(sql"""create table if not exists url (
    url text primary key);""")

proc contains*(db: DbConn, uri: Uri): bool =
  let hits = db.getRow(
    sql"""select * from url where url = ?""", $uri
  )
  if hits[0] != "":
    result = true

proc append*(db: DbConn, uris: seq[Uri]) =
  for uri in uris:
    db.exec(
      sql"""insert into url(url) values(?)""", $uri
    )
