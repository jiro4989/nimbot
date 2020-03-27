#!/bin/sh

set -eu

echo "fuck --------------------------"
mongo -u 'root' -p "$MONGO_INITDB_ROOT_PASSWORD" << EOF
  use nimbot

  db.getSiblingDB('nimbot').createCollection('code')
  db.getSiblingDB('nimbot').createCollection('log')

  var users = [
    {
      user: "writer",
      pwd: "password",
      roles: [
        { role: "readWrite", db: "nimbot" }
      ]
    }
  ]

  for (var i=0; i<users.length; i++) {
    db.createUser(users[i]);
  }

EOF
echo "fuckoff --------------------------"
