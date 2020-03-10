import asyncdispatch, httpClient, json, os, strutils, sequtils
from uri import decodeUrl

import jester

router myrouter:
  post "/play":

    let
      scriptDir = getCurrentDir() / "tmp" / "script"
      scriptFile = scriptDir / "main.nim"

    if existsFile(scriptFile):
      resp %*{"status":"他の方が実行中です"}
    else:
      let
        param = request.body()
        paramMap = param.split("&").mapIt(it.split("="))
        body = paramMap.filterIt(it[0] == "text")[0][1].decodeUrl(true)
      writeFile(scriptFile, body)
      resp %*{"status":"ok"}
  get "/ping":
    resp %*{"status":"ok"}

proc main =
  var port = getEnv("NIMBOT_SERVER_PORT", "1234").parseInt().Port
  var settings = newSettings(port = port)
  var jester = initJester(myrouter, settings = settings)
  jester.serve()

when isMainModule and not defined modeTest:
  main()
