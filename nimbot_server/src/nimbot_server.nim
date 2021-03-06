import asyncdispatch, httpClient, json, os, strutils, sequtils, times
from uri import decodeUrl
from strformat import `&`

import jester, nimongo/bson, nimongo/mongo

const
  helpMsg = """
nimbot is a toy bot for Nim user.

*Usage:*
1. compile and execute code. you can use `/nimbot <c | compiler> [devel]`.

/nimbot compiler

```
echo "hello"
```
"""

proc getParam(p: seq[seq[string]], key: string): string =
  result = p.filterIt(it[0] == key)[0][1].decodeUrl(true)

proc getCodeBlock(raw: string): string =
  ## コードブロック記法がくくられてるエリアの文字列のみを取得する。
  ## コードブロック文字自体は返さない。
  var startPos, endPos: int
  for i, c in raw:
    if c == '`':
      startPos = i
      break
  for i in countdown(raw.len-1, 0):
    let c = raw[i]
    if c == '`':
      endPos = i
      break
  result = raw[startPos..endPos].strip(chars={'`'})

router myrouter:
  post "/play":
    let
      param = request.body()

    echo json.`%*`({"level":"info", "msg":"request begin"})

    let
      paramMap = param.split("&").mapIt(it.split("="))
      text = paramMap.getParam("text")
      userName = paramMap.getParam("user_id")
      lines = text.split("\n")

    echo json.`%*`({"level":"info", "msg":"code: " & text})

    if lines.len < 1:
      resp json.`%*`({"status":"illegal commands. see '/nimbot help'."})
      return

    let
      args = lines[0].strip.split(" ")

    if args[0] in ["compiler", "c"]:
      echo json.`%*`({"level":"info", "msg":"runs compile action"})

      var tag = "stable"
      if 2 <= args.len:
        if args[1] == "devel":
          tag = "devel"
        else:
          resp json.`%*`({"status": &"illegal compiler: {args[1]}"})
          return
      let
        code = text.getCodeBlock()
      echo json.`%*`({"level":"info", "code":code})

      let
        dbHost = getEnv("DB_HOST")
        dbPort = getEnv("DB_PORT").parseUint.uint16
        dbName = getEnv("DB_DBNAME")
        user = getEnv("DB_USER")
        pass = getEnv("DB_PASSWORD")

      var db = newMongoDatabase(&"mongodb://{user}:{pass}@{dbHost}:{dbPort}/{dbName}")
      let now = now()
      let
        collection = db["code"]
        record = bson.`%*`({
          "userId": userName,
          "compiler": tag,
          "code": code,
          "created_at": $now,
          })
        reply = collection.insert(record)
      echo json.`%*`({"level":"info", "msg":"request end", "ok":reply.ok, "count":reply.n})
      if reply.ok:
        resp json.`%*`({"status":"ok"})
      else:
        resp json.`%*`({"status":"ng"})
      return

    if args[0] in ["help", "h"]:
      resp helpMsg.strip
      return

    echo json.`%*`({"level":"info", "msg":"finish server"})
    resp json.`%*`({"status":"not supported"})

  get "/ping":
    resp json.`%*`({"status":"ok"})

proc main =
  var port = getEnv("PORT", "1234").parseInt().Port
  var settings = newSettings(port = port)
  var jester = initJester(myrouter, settings = settings)
  jester.serve()

when isMainModule and not defined modeTest:
  main()
