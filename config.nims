task upDev, "start dev application":
  selfExec "downDev"
  exec "docker-compose up -d"
  exec "docker-compose ps"

task upLog, "start log":
  exec "docker-compose -f prd-log.yml up -d"

task upDb, "start database":
  exec "docker-compose -f prd-db.yml up -d"

task upApp, "start application":
  exec "docker-compose -f prd-docker-compose.yml up -d"

task upAll, "start all application":
  selfExec "downAll"
  selfExec "upLog"
  selfExec "upDb"
  selfExec "upApp"
  exec "docker-compose -f prd-log.yml -f prd-db.yml -f prd-docker-compose.yml ps"

task downDev, "down dev application":
  exec "docker-compose down"

task downLog, "down log":
  exec "docker-compose -f prd-log.yml down"

task downDb, "down database":
  exec "docker-compose -f prd-db.yml down"

task downApp, "down application":
  exec "docker-compose -f prd-docker-compose.yml down"

task downAll, "down all application":
  selfExec "downApp"
  selfExec "downDb"
  selfExec "downLog"

task tests, "test post":
  withDir "nimbot_server":
    exec "nimble test -Y"
