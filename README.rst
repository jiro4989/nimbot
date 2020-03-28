======
nimbot
======

Slackのチャットメッセージを読み取ってNimのコードをコンパイルして実行し、その結果
をSlackに返却するBotです。

|image-demo-top|

使い方
======

Slackの ``nimbot`` チャンネルで、チャット欄に以下のテキストを入力して送信します
。

::

  /nimbot c

  ```
  echo NimVersion
  ```


これは Nim_ [#f1]_ のコンパイラのバージョンを出力する Nim_ のコードです。
Slackのコードブロック記法内に、任意の Nim_ のコードを記載できます。

処理フロー
==========

Slackの |slash-commands| [#f2]_ を使用してNimのコードを送信します。

送信すると、サーバ側の ``nimbot_server`` の `POST /play` エンドポイントにデータ
がPOSTされます。POSTされたデータをパースし、MongoDBの ``code`` コレクションにド
キュメントが保存されます。保存後、一旦Slackのユーザに ``OK`` というレスポンスが
返却されます。

レスポンス返却後、APIサーバとは別で起動する ``nimbot_executor`` がMongoDBの
``code`` を定期的に確認します。 ``code`` にドキュメントが存在するとき、
``nimbot_executor`` はドキュメント内の ``code`` 要素を取得し、Dockerコンテナを起
動して、コンテナ内でNimのコードをコンパイルして実行します。実行結果の標準出力と
標準エラー出力を取得し、Slackの |incomming-webhook| [#f3]_ にデータをPOSTします。

以下はそのシーケンス図です。

|image-data-flow|

Usave
=====

.. code-block:: shell

   docker-compose -f compiler.yml build
   docker-compose up


Starts for production.

.. code-block:: shell

   docker-compose -f compiler.yml build
   docker-compose -f .github/build.yml build
   docker-compose -f docker-compose.yml -f prd.yml up

.. |image-demo-top| image:: ./docs/demo_top.png
.. |image-data-flow| image:: ./out/docs/data_flow/data_flow.svg

.. _Nim: Nim https://nim-lang.org/
.. |nim| replace:: `Nim <https://nim-lang.org/>`_
.. |slash-commands| replace:: `Slash Commands <https://api.slack.com/interactivity/slash-commands>`_
.. |incoming-webhook| replace:: `Incoming Webhook <https://slack.com/intl/ja-jp/help/articles/115005265063>`_

.. [#f1] 効率的で、表現力豊かで、エレガントなプログラミング言語。このBotもこれで書かれている )
.. [#f2] ``/`` で始まるコマンドでBotと対話的にやり取りをするためのSlackインテグレーション
.. [#f3] 任意のSlackチャンネルにデータを送信するためのWebhook
