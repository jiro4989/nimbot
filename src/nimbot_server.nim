import asyncdispatch, httpClient, json, os, strutils, sequtils
from uri import decodeUrl
from strformat import `&`

import jester

import private/common

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

proc getCodeBlock(lines: openArray[string]): string =
  ## コードブロック記法がくくられてるエリアの文字列のみを取得する。
  ## コードブロック文字自体は返さない。
  var getFlag: bool
  var codeLines: seq[string]
  for line in lines:
    if line.startsWith("```"):
      if not getFlag:
        getFlag = not getFlag
        continue
      else:
        break
    if getFlag:
      codeLines.add(line)
  result = codeLines.join("\n")

router myrouter:
  post "/play":
    if existsFile(scriptFile):
      resp %*{"status":"other user is using. wait a second."}
      return

    let
      param = request.body()
      paramMap = param.split("&").mapIt(it.split("="))
      text = paramMap.getParam("text")
      userName = paramMap.getParam("user_id")
      lines = text.split("\n")

    if lines.len < 1:
      resp %*{"status":"illegal commands. see '/nimbot help'."}
      return

    let
      args = lines[0].strip.split(" ")

    if args[0] in ["compiler", "c"]:
      var tag = "latest"
      if 2 <= args.len:
        if args[1] == "devel":
          tag = "devel"
        else:
          resp %*{"status": &"illegal compiler: {args[1]}"}
          return
      let
        code = lines[1..^1].getCodeBlock()
        param = %*{ "userId": userName, "compiler": tag, "code": code }
      writeFile(paramFile, $param)
      resp %*{"status":"ok"}
      return

    if args[0] in ["help", "h"]:
      resp helpMsg.strip
      return

    resp %*{"status":"not supported"}

  get "/ping":
    resp %*{"status":"ok"}

proc main =
  var port = getEnv("NIMBOT_SERVER_PORT", "1234").parseInt().Port
  var settings = newSettings(port = port)
  var jester = initJester(myrouter, settings = settings)
  jester.serve()

when isMainModule and not defined modeTest:
  main()
