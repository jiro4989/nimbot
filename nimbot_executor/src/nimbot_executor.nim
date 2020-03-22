import asyncdispatch, httpClient, json, os, osproc, strutils, strformat, streams, logging
from strformat import `&`

import nimongo/bson, nimongo/mongo

addHandler(newConsoleLogger(lvlInfo, fmtStr = "$levelname "))

const
  statusOk = 0
  statusTimeout = 1
  statusSystemError = 100

proc readStream(strm: var Stream): string =
  defer: strm.close()
  result = strm.readAll()

proc runCommand(command: string, args: openArray[string], timeout: int = 3): (string, string, int, string) =
  ## ``command`` を実行し、標準出力と標準エラー出力を返す。
  ## timeout は秒を指定する。
  var
    p = startProcess(command, args = args, options = {poUsePath})
    stdoutStr, stderrStr: string
  defer: p.close()

  let
    timeoutMilSec = timeout * 1000
    exitCode = waitForExit(p, timeout = timeoutMilSec)

  # 処理結果の判定
  var
    status: int
    msg: string
  if exitCode == 0:
    status = statusOk
  elif exitCode == 137:
    status = statusTimeout
    msg = &"timeout: {timeout} second"
  else:
    status = statusSystemError
    msg = &"failed to run command: command={command}, args={args}"

  # 出力の取得
  block:
    var strm = p.outputStream
    stdoutStr = strm.readStream()
  block:
    var strm = p.errorStream
    stderrStr = strm.readStream()

  result = (stdoutStr, stderrStr, status, msg)

proc runCommandOnContainer(scriptFile: string): (string, string, int, string) =
  let args = [
    "c",
    "-d:release",
    "-r",
    "--hints:off",
    "--verbosity:0",
    scriptFile,
    ]
  let timeout = getEnv("SLACKBOT_NIM_REQUEST_TIMEOUT", "10").parseInt
  result = runCommand("nim", args, timeout)

let
  dbHost = getEnv("DB_HOST")
  dbPort = getEnv("DB_PORT").parseUint.uint16
  dbName = getEnv("DB_DBNAME")
  user = getEnv("DB_USER")
  pass = getEnv("DB_PASSWORD")

info "start executor"
var db = newMongoDatabase(&"mongodb://{user}:{pass}@{dbHost}:{dbPort}/{dbName}")
let
  collCode = db["code"]
  collLog = db["log"]
  query = bson.`%*`({"compiler": "latest"})
  n = bson.`%*`({})

while true:
  sleep 500

  let reply = waitFor collCode.findAndModify(query, n, n, false, false, remove=true)
  let record = reply.bson["value"]
  if record.kind == BsonKindNull:
    continue
  let reply2 = collLog.insert(record)
  if not reply2.ok:
    error "error"

  const scriptFile = "/tmp/main.nim"
  try:
    let
      userId = record["userId"].toString
      code = record["code"].toString
      tag = record["compiler"].toString
      #image = &"jiro4989/nimbot/runtime:{tag}"
    writeFile(scriptFile, code)
    let (stdout, stderr, exitCode, msg) = runCommandOnContainer(scriptFile)
    info &"code={code} stdout={stdout} stderr={stderr} exitCode={exitCode} msg={msg}"

    let rawBody = @[
      &"<@{userId}>",
      "*code:*", "```", code, "```",
      "*stdout:*", "```", stdout, "```",
      "*stderr:*", "```", stderr, "```",
    ].join("\n")
    let body = json.`%*`({ "text":rawBody })

    info "start"
    let url = os.getEnv("SLACK_URL")
    var client = newHttpClient()
    let resp = client.post(url, $body)
    info resp[]
    info "finish"
  except:
    error getCurrentExceptionMsg()
  finally:
    removeFile(scriptFile)
