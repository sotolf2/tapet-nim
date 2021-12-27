import 
  clapfn,
  config,
  core,
  wallhaven,
  std/db_sqlite,
  std/tables,
  std/os,
  std/strutils


# First parse arguments

var parser = ArgumentParser(programName: "tapet", fullName: "A background switcher",
                            description: "Downloads and switches background images",
                            version: "0.1", author: "sotolf2")
parser.addSwitchArgument(
  shortname = "-n",
  longName = "--next",
  default = false,
  help = "Sets the next wallpaper."
)
parser.addSwitchArgument(
  shortname = "-f",
  longName = "--favorite",
  default = false,
  help = "Saves the current wallpaper in the favorites."
)
parser.addSwitchArgument(
  shortname = "-r",
  longName = "-random",
  default = false,
  help = "Set a random wallpaper from the favorites directory"
)
parser.addSwitchArgument(
  shortname = "-R",
  longName = "--restore",
  default = false,
  help = "Restore the current wallpaper"
)
parser.addSwitchArgument(
  shortname = "-u",
  longName = "--update",
  default = false,
  help = "Updates new wallpapers"
)
parser.addSwitchArgument(
  shortname = "-d",
  longName = "--daemon",
  default = false,
  help = "Runs in the background and updates wallpapers automatically"
)

let args = parser.parse()

# setup configuration
let configurationHome = getConfigDir()
let confPath = joinPath(configurationHome, "tapet")
let confFile = joinPath(confPath, "tapet.ini")
let stateDb = joinPath(confPath, "tapet.sqlite")

let configuration = parseConfig(confFile)
let state = open(stateDb, "", "", "")
ensureState(state)

# do what the user arked for
if args["next"].parseBool:
  setNewDownloaded(configuration, state)

if args["favorite"].parseBool:
  copyToFavorite(configuration, state)

if args["random"].parseBool:
  setRandomFavorite(configuration, state)

if args["restore"].parseBool:
  restoreBackground(configuration, state)

if args["update"].parseBool:
  downloadImages(configuration, state)

if args["daemon"].parseBool:
  let sleepMin = configuration.tapet.interval
  let sleepDuration = sleepMin * 60000
  let counterLim = configuration.tapet.downloadEvery
  var counter = 0
  while true:
    setNewDownloaded(configuration, state)
    if counter == counterLim:
      downloadImages(configuration, state)
      counter = 0
    sleep(sleepDuration)
