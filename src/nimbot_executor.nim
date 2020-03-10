import httpClient, json, os, osproc, strutils, strformat, streams, logging

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

let scriptDir = getCurrentDir() / "tmp" / "script"
let scriptFile = scriptDir / "main.nim"

while true:
  sleep 500

  if not existsFile(scriptFile):
    info &"'{scriptFile}' was not existed"
    continue

  try:
    let code = readFile(scriptFile)
    let (stdout, stderr, exitCode, msg) = runCommandOnContainer(scriptFile, "nimlang/nim")
    info &"code={code} stdout={stdout} stderr={stderr} exitCode={exitCode} msg={msg}"

    let rawBody = @[
      "*code:*", "```", code, "```",
      "*stdout:*", stdout,
      "*stderr:*", stderr,
    ].join("\n")
    let body = %*{ "text":rawBody }

    let url = os.getEnv("NIMBOT_EXECUTOR_SLACK_URL")
    var client = newHttpClient()
    discard client.post(url, $body)
  except:
    error getCurrentExceptionMsg()
  finally:
    removeFile(scriptFile)
