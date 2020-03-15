import unittest

include nimbot_server

suite "getCodeBlock":
  test "1 line":
    let in1 = ["```", "echo 1", "```"]
    let got = "echo 1"
    check getCodeBlock(in1) == got
  test "2 line":
    let in1 = ["```", "echo 1", "echo 2", "```"]
    let got = "echo 1\necho 2"
    check getCodeBlock(in1) == got
  test "2 line":
    let in1 = ["", "```", "echo 1", "echo 2", "```", "test", "sushi"]
    let got = "echo 1\necho 2"
    check getCodeBlock(in1) == got
