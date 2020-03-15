import os

let
  scriptDir = getCurrentDir() / "tmp" / "script"
  scriptFile* = scriptDir / "main.nim"
  paramFile* = scriptDir / "request_param.json"
