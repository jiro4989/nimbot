import os, strformat

let
  composeFile = "docker-compose.yml"
  composePrdFluentd = "prd"/"fluentd"/composeFile
  composePrdMongoDb = "prd"/"mongodb"/composeFile
  composePrdNimbot = "prd"/"nimbot"/composeFile
  composePrdFiles = [composePrdFluentd, composePrdMongoDb, composePrdNimbot]

proc upService(compose: string) =
  exec &"docker-compose -f {compose} up -d"

proc downService(compose: string) =
  exec &"docker-compose -f {compose} down"

task upDev, "start dev application":
  selfExec "downDev"
  exec "docker-compose up -d"
  exec "docker-compose ps"

task upLog, "start log":
  upService(composePrdFluentd)

task upDb, "start database":
  upService(composePrdMongoDb)

task upApp, "start application":
  upService(composePrdNimbot)

task status, "print status":
  for f in composePrdFiles:
    exec &"docker-compose -f {f} ps"

task upAll, "start all application":
  selfExec "downAll"
  selfExec "upLog"
  selfExec "upDb"
  selfExec "upApp"
  selfExec "status"

task downDev, "down dev application":
  exec "docker-compose down"

task downLog, "down log":
  downService(composePrdFluentd)

task downDb, "down database":
  downService(composePrdMongoDb)

task downApp, "down application":
  downService(composePrdNimbot)

task downAll, "down all application":
  selfExec "downApp"
  selfExec "downDb"
  selfExec "downLog"

task buildImage, "build prd images":
  for f in composePrdFiles:
    exec &"docker-compose -f {f} build"

task tests, "test post":
  withDir "nimbot_server":
    exec "nimble test -Y"
