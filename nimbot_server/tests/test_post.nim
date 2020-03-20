import unittest, uri, httpclient

const url = "http://localhost:4001/play"

suite "POST /play":
  setup:
    const prefix = "user_id=test_user&text=" 
  test "normal case":
    const code = """c

```
echo "test"
```
"""
    let encodedText = prefix & code.encodeUrl(true)
    var client = newHttpClient()
    echo client.postContent(url, encodedText)
