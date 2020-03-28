import asyncdispatch, httpClient, json, os, osproc, strutils, strformat, streams, logging, times
from strformat import `&`

import nimongo/bson, nimongo/mongo

addHandler(newConsoleLogger(lvlInfo, fmtStr = "$levelname ", useStderr = true))

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

proc runCommandOnContainer(scriptFile, image: string): (string, string, int, string) =
  let hostPwd = getEnv("HOST_PWD")
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
    "-v", &"{hostPwd}/executor/main.nim:/tmp/main.nim:ro",
    "-i", image,
    "bash", "-c", &"sync && cd /tmp && nim c -d:release --hints:off --verbosity:0 main.nim && ./main | stdbuf -o0 head -c 100K",
    ]
  let timeout = getEnv("COMMAND_TIMEOUT", "10").parseInt
  result = runCommand("docker", args, timeout)

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
  query = bson.`%*`({"compiler": "stable"})
  n = bson.`%*`({})

while true:
  sleep 500

  let reply = waitFor collCode.findAndModify(query, n, n, false, false, remove=true)
  var record = reply.bson["value"]
  if record.kind == BsonKindNull:
    continue
  record["created_at"] = ($now()).toBson()
  let reply2 = collLog.insert(record)
  if not reply2.ok:
    error "error"
    continue

  let scriptFile = "."/"executor"/"main.nim"
  try:
    let
      userId = record["userId"].toString
      code = record["code"].toString
      compiler = record["compiler"].toString
      image = &"jiro4989/nimbot:compiler-{compiler}"
    info &"start executer: userID={userId} code={code} image={image}"
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

    info "post to slack"
    let url = os.getEnv("SLACK_URL")
    var client = newHttpClient()
    let resp = client.post(url, $body)
    info resp[]
    info "finish executer:"
  except:
    error getCurrentExceptionMsg()
  finally:
    removeFile(scriptFile)
