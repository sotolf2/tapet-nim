import
  config,
  core,
  jsony,
  std/db_sqlite,
  std/httpclient,
  std/net,
  std/strformat,
  std/uri

type Thumbs = object
  large: string
  original: string
  small: string

type Data = object
  id: string
  url: string
  views: int
  favorites: int
  source: string
  purity: string
  category: string
  dimension_x: int
  dimension_y: int
  resolution: string
  ratio: string
  file_size: int
  file_type: string
  created_at: string
  colors: seq[string]
  path: string
  thumbs: Thumbs

type Meta = object
  current_page: int
  last_page: int
  per_page: int
  total: int
  query: string
  seed: string

type Page = object
  data: seq[Data]
  meta: Meta

const API_URL = parseUri "https://wallhaven.cc/api/v1/"

proc getUrisFromPage(client: HttpClient, tags: string, pageNum: int): seq[Uri] =
  let uri = API_URL / "search" ? {"q": tags, "page": $pageNum}
  let response = client.get(uri)
  let page = response.body.fromJson(Page)
  for data in page.data:
    result.add(data.path.parseUri)

proc getUrisFromPage(client: HttpClient,configuration: Config, pageNum: int): seq[Uri] =
  let tags = configuration.wallhaven.tags
  getUrisFromPage(client, tags, pageNum)

proc downloadImages*(configuration: Config, state: DbConn) =
  let numDownloaded = countDownloaded(configuration)
  let toDownload = configuration.wallhaven.downloadNum - numDownloaded
  let client = newHttpClient(sslContext=newContext(verifyMode=CVerifyPeer))

  # Wallhaven gives us 24 responses per page, so we have to go on
  # until we get as many as we need.
  var pageNum = 1
  var urls: seq[Uri]

  while urls.len < toDownload:
    var newUrls = client.getUrisFromPage(configuration, pageNum)

    for url in newUrls:
      if urls.len <= toDownload and not state.contains(url):
        urls.add(url)
    
    pageNum += 1

  for url in urls:
    echo fmt"Downloading: {$url}"
    client.downloadImage(configuration, url)

  state.append(urls)



if isMainModule:
  let client = newHttpClient(sslContext=newContext(verifyMode=CVerifyPeer))
  let urls = client.getUrisFromPage("", 1)
  echo urls

