const express = require("express");
const router = express.Router();
const expressJwt = require("express-jwt");
const spawn = require("child_process").spawn;

var processingCommand = false;

function isCommandRunning(req, res, next) {
  if (processingCommand) {
    res.status(409).send("command processing...");
  } else {
    next();
  }
}

//scale up instance
router.post(
  "/up",
  expressJwt({ secret: process.env.JWT_SECRET, algorithms: ["HS256"] }),
  isCommandRunning,
  (req, res) => {
    runCommand("../scale-up.sh", req.app.get('socketio'));
    res.sendStatus(200);
  }
);

//scale down instance
router.post(
  "/down",
  expressJwt({ secret: process.env.JWT_SECRET, algorithms: ["HS256"] }),
  isCommandRunning,
  (req, res) => {
    runCommand("../scale-down.sh", req.app.get('socketio'));
    res.sendStatus(200);
  }
);

//change region
router.post(
  "/region",
  expressJwt({ secret: process.env.JWT_SECRET, algorithms: ["HS256"] }),
  isCommandRunning,
  (req, res) => {
    res.sendStatus(200);
  }
);

//get status
router.post(
  "/status",
  expressJwt({ secret: process.env.JWT_SECRET, algorithms: ["HS256"] }),
  isCommandRunning,
  (req, res) => {
    res.sendStatus(200);
  }
);

//nuke and run
router.post(
  "/destroy",
  expressJwt({ secret: process.env.JWT_SECRET, algorithms: ["HS256"] }),
  isCommandRunning,
  (req, res) => {
    res.sendStatus(200);
  }
);

router.use(function (err, req, res, next) {
  if (err.name === "UnauthorizedError") {
    res.status(401).send("invalid token...");
  }
});

function runCommand(command, io) {
  processingCommand = true;
  var myProcess = spawn(command);
  myProcess.stdout.setEncoding("utf-8");
  myProcess.stdout.on("data", function (data) {
    io.sockets.emit("process_data", data);
    console.log(data);
  });

  myProcess.stderr.setEncoding("utf-8");
  myProcess.stderr.on("error", function (data) {
    io.sockets.emit("process_data", data);
    console.log(data);
  });

  myProcess.on("exit", () => {
    processingCommand = false;
    console.log('command complete');
  });
}

module.exports = router;
