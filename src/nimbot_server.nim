import asyncdispatch, httpClient, json, os, strutils, sequtils, logging
from uri import decodeUrl
from strformat import `&`

import jester, nimongo.bson, nimongo.mongo

import private/common

addHandler(newConsoleLogger(lvlInfo, fmtStr = verboseFmtStr, useStderr = true))

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
    if existsFile(scriptFile):
      resp json.`%*`({"status":"other user is using. wait a second."})
      return

    let
      param = request.body()

    info &"param={param}"

    let
      paramMap = param.split("&").mapIt(it.split("="))
      text = paramMap.getParam("text")
      userName = paramMap.getParam("user_id")
      lines = text.split("\n")

    info &"text={text}"

    if lines.len < 1:
      resp json.`%*`({"status":"illegal commands. see '/nimbot help'."})
      return

    let
      args = lines[0].strip.split(" ")

    if args[0] in ["compiler", "c"]:
      info "action=compile"

      var tag = "latest"
      if 2 <= args.len:
        if args[1] == "devel":
          tag = "devel"
        else:
          resp json.`%*`({"status": &"illegal compiler: {args[1]}"})
          return
      let
        code = text.getCodeBlock()
      info &"code={code}"

      let
        dbHost = getEnv("NIMBOT_SERVER_DB_HOST")
        dbPort = getEnv("NIMBOT_SERVER_DB_PORT").parseUint.uint16
      var
        mongoClient = newMongo(host=dbHost, port=dbPort)
      doAssert mongoClient.connect()
      let
        collection = mongoClient["db"]["code"]
        record = bson.`%*`({"userId": userName, "compiler": tag, "code": code})
        reply = collection.insert(record)
      info &"ok={reply.ok} count={reply.n}"
      if reply.ok:
        resp json.`%*`({"status":"ok"})
      else:
        resp json.`%*`({"status":"ng"})
      return

    if args[0] in ["help", "h"]:
      resp helpMsg.strip
      return

    resp json.`%*`({"status":"not supported"})

  get "/ping":
    resp json.`%*`({"status":"ok"})

proc main =
  var port = getEnv("NIMBOT_SERVER_PORT", "1234").parseInt().Port
  var settings = newSettings(port = port)
  var jester = initJester(myrouter, settings = settings)
  jester.serve()

when isMainModule and not defined modeTest:
  main()
