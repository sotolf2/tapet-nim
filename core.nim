import
  config,
  std/algorithm,
  std/db_sqlite,
  std/deques,
  std/httpclient,
  std/net,
  std/os,
  std/osproc,
  std/random,
  std/strutils,
  std/times,
  std/uri

proc downloadImage*(client: HttpClient, configuration: Config, uri: Uri) =
  let filename = uri.path.split("/")[^1]
  let filepath = joinPath(configuration.tapet.downloadsFolder, filename).expandTilde
  client.downloadFile(uri, filepath)

proc countDownloaded*(configuration: Config): int =
  for file in walkDir configuration.tapet.downloadsFolder.expandTilde:
    result += 1

proc randomFromFolder(path: string): string =
  var paths: seq[string]
  for file in walkDir(path):
    paths.add(file.path)

  randomize()
  sample(paths)

proc randomDownloaded(configuration: Config): string =
  randomFromFolder configuration.tapet.downloadsFolder.expandTilde

proc randomFavorite(configuration: Config): string =
  randomFromFolder configuration.tapet.favoritesFolder.expandTilde

type FileWDate = tuple
  modTime: Time
  path: string

proc compFiles(this, other: FileWDate): int =
  cmp(this.modTime, other.modTime)

proc cleanupPrevious(configuration: Config) =
  var files: seq[FileWDate]
  for file in walkDir(configuration.tapet.previousFolder.expandTilde):
    files.add((file.path.getLastModificationTime, file.path))
  files.sort(compFiles)
  files.reverse()
  var qu = toDeque(files)
  while qu.len() > configuration.tapet.previousKeep:
    let cur = qu.popFirst()
    removeFile(cur.path)


proc moveToPrevious(configuration: Config, path: string) =
  let folder = configuration.tapet.previousFolder.expandTilde
  let filename = path.extractFilename
  let destination = joinPath(folder, filename)
  moveFile(path, destination)

  cleanupPrevious(configuration)

proc setWithFeh(configuration: Config, path: string) =
  let program = "feh --bg-fill "
  let cmd = program & path
  let errorCode = execCmd(cmd)
  if errorCode != 0:
    echo "failed to execute feh, are you sure it's installed?"

proc setWithNitrogen(configuration: Config, path: string) =
  let program = "nitrogen --set-scaled "
  let cmd = program & path
  let errorCode = execCmd(cmd)
  if errorCode != 0:
    echo "failed to execute nitrogen, are you sure it's installed?"

proc setBackground(configuration: Config, path: string) =
  case configuration.tapet.wallpaperSetter
  of "feh": setWithFeh(configuration, path)
  of "nitrogen": setWithNitrogen(configuration, path)
  else: echo("I don't know about this setter: ", configuration.tapet.wallpaperSetter)

proc setNewDownloaded*(configuration: Config, state: DbConn) =
  var curState = state.getState()
  var newWallpaper = curState.currentWallpaper
  while newWallpaper == curState.currentWallpaper:
    newWallpaper = randomDownloaded(configuration)

  if curState.isDownloaded:
    moveToPrevious(configuration, curState.currentWallpaper)

  curstate.currentWallpaper = newWallpaper
  curstate.isDownloaded = true
  setState(state, curstate)

  setBackground(configuration, newWallpaper)
  
proc restoreBackground*(configuration: Config, state: DbConn) =
  let curState = getState(state)
  setBackground(configuration, curState.currentWallpaper)

proc copyToFavorite*(configuration: Config, state: DbConn) =
  let curState = getState(state)
  let folder = configuration.tapet.favoritesFolder.expandTilde
  let filename = curState.currentWallpaper.extractFilename
  let destination = joinPath(folder, filename)
  copyFile(curState.currentWallpaper, destination)

proc setRandomFavorite*(configuration: Config, state: DbConn) =
  var curState = getState(state)
  let newWallpaper = randomFavorite(configuration)

  if curState.isDownloaded:
    moveToPrevious(configuration, curState.currentWallpaper)

  curState.isDownloaded = false
  curState.isFavorite = true
  curState.currentWallpaper = newWallpaper
  setState(state, curState)

  setBackground(configuration, curState.currentWallpaper)
