import asyncdispatch, httpClient, json, os, osproc, strutils, strformat, streams, logging
from strformat import `&`

import nimongo.bson, nimongo.mongo

import private/common

addHandler(newConsoleLogger(lvlInfo, fmtStr = verboseFmtStr, useStderr = true))

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

proc runCommandOnContainer(scriptFile, containerName: string): (string, string, int, string) =
  let args = [
    "run",
    "--rm",
    "--net=none",
    "-m", "256MB",
    "--oom-kill-disable",
    "--pids-limit", "1024",
    "--log-driver=json-file",
    "--log-opt", "max-size=50m",
    "--log-opt", "max-file=3",
    "-v", &"{scriptFile}:/tmp/main.nim:ro",
    "-i", containerName,
    "bash", "-c", &"sync && cd /tmp && nim c -d:release --hints:off --verbosity:0 main.nim && ./main | stdbuf -o0 head -c 100K",
    ]
  let timeout = getEnv("SLACKBOT_NIM_REQUEST_TIMEOUT", "10").parseInt
  result = runCommand("docker", args, timeout)

let
  dbHost = getEnv("NIMBOT_EXECUTOR_DB_HOST")
  dbPort = getEnv("NIMBOT_EXECUTOR_DB_PORT").parseUint.uint16
  dbName = getEnv("NIMBOT_EXECUTOR_DB_DBNAME")
  user = getEnv("NIMBOT_EXECUTOR_DB_USER")
  pass = getEnv("NIMBOT_EXECUTOR_DB_PASSWORD")

var db = newMongoDatabase(&"mongodb://{user}:{pass}@{dbHost}:{dbPort}/{dbName}")
let
  collCode = db["code"]
  collLog = db["log"]
  query = bson.`%*`({"userId": "test_user"})
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

  if not existsFile(paramFile):
    continue

  try:
    let
      obj = readFile(paramFile).parseJson
      userId = obj["userId"].getStr
      code = obj["code"].getStr
      tag = obj["compiler"].getStr
      image = &"jiro4989/nimbot/runtime:{tag}"
    writeFile(scriptFile, code)
    let (stdout, stderr, exitCode, msg) = runCommandOnContainer(scriptFile, image)
    info &"code={code} stdout={stdout} stderr={stderr} exitCode={exitCode} msg={msg}"

    let rawBody = @[
      &"<@{userId}>",
      "*code:*", "```", code, "```",
      "*stdout:*", "```", stdout, "```",
      "*stderr:*", "```", stderr, "```",
    ].join("\n")
    let body = json.`%*`({ "text":rawBody })

    let url = os.getEnv("NIMBOT_EXECUTOR_SLACK_URL")
    var client = newHttpClient()
    discard client.post(url, $body)
  except:
    error getCurrentExceptionMsg()
  finally:
    removeFile(paramFile)
    removeFile(scriptFile)
