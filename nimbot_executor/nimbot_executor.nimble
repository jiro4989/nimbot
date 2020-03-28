# Package

version       = "0.1.0"
author        = "jiro4989"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
bin           = @["nimbot_executor"]
binDir        = "bin"


# Dependencies

requires "nim >= 1.0.6"
#requires "nimongo#6b518eb3792876aaf496aede5005f43f5e3d095d"
requires "https://github.com/jiro4989/nimongo#head"
