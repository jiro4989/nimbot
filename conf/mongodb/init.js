db.dropAllUsers();

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
