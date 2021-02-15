const express = require("express");
const app = express();
const server = require("http").Server(app);
const io = require("socket.io")(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

const socketioJwt = require("socketio-jwt");
const expressJwt = require("express-jwt");
const jwt = require("jsonwebtoken");

const cors = require("cors");
const spawn = require("child_process").spawn;

const PORT = process.env.PORT;
const HOST = "0.0.0.0";

io.use(
  socketioJwt.authorize({
    secret: process.env.JWT_SECRET,
    handshake: true,
  })
);

app.use(express.urlencoded({ extended: true }));

var corsOptions = {
  origin: ["*"], //for now
  optionsSuccessStatus: 200,
};
app.use(cors(corsOptions));

app.get("/", async (req, res) => {
  //return user page
});

app.post("/v1/api/login", (req, res) => {
  const { username, password } = req.body;
  console.log(process.env.API_USERNAME);

  if (
    password == process.env.API_PASSWORD &&
    username == process.env.API_USERNAME
  ) {
    //Maybe need to make more secure but we have to put password into env var anyway when we create the function

    const accessToken = jwt.sign(
      { username: username },
      process.env.JWT_SECRET
    );
    res.json({
      accessToken,
    });
  } else {
    res.status(401).send("username or password incorrect");
  }
});

//scale up instance

app.post(
  "/v1/api/up",
  expressJwt({ secret: process.env.JWT_SECRET, algorithms: ["HS256"] }),
  (req, res) => {
    runCommand("./test.sh");
    res.sendStatus(200);
  }
);

//scale down instance
app.post(
  "/v1/api/down",
  expressJwt({ secret: process.env.JWT_SECRET, algorithms: ["HS256"] }),
  (req, res) => {
    res.sendStatus(200);
  }
);

//setup - would require post data for all of the options and to modify the script to accept flags
app.post(
  "/v1/api/setup",
  expressJwt({ secret: process.env.JWT_SECRET, algorithms: ["HS256"] }),
  (req, res) => {
    res.sendStatus(200);
  }
);

//change region
app.post(
  "/v1/api/region",
  expressJwt({ secret: process.env.JWT_SECRET, algorithms: ["HS256"] }),
  (req, res) => {
    res.sendStatus(200);
  }
);

//get status
app.post(
  "/v1/api/status",
  expressJwt({ secret: process.env.JWT_SECRET, algorithms: ["HS256"] }),
  (req, res) => {
    res.sendStatus(200);
  }
);

//nuke and run
app.post(
  "/v1/api/destroy",
  expressJwt({ secret: process.env.JWT_SECRET, algorithms: ["HS256"] }),
  (req, res) => {
    res.sendStatus(200);
  }
);

app.use(function (err, req, res, next) {
  if (err.name === "UnauthorizedError") {
    res.status(401).send("invalid token...");
  }
});

function runCommand(command) {
  var myProcess = spawn(command);
  myProcess.stdout.setEncoding("utf-8");
  myProcess.stdout.on("data", function (data) {
    io.sockets.emit("process_data", data);
  });
  myProcess.stderr.setEncoding("utf-8");
  myProcess.stderr.on("data", function (data) {
    io.sockets.emit("process_data", data);
  });
}

server.listen(PORT, HOST);
console.log(`Running on http://${HOST}:${PORT}`);
