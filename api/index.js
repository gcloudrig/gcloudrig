const express = require("express");
const app = express();
const server = require("http").Server(app);
const cors = require("cors");
const commandRoutes = require("./v1/commands");
const authRoutes = require("./v1/auth");
var bodyParser = require('body-parser');

const PORT = process.env.PORT;
const HOST = "0.0.0.0";

const socketioJwt = require("socketio-jwt");

const io = require("socket.io")(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

io.use(
  socketioJwt.authorize({
    secret: process.env.JWT_SECRET,
    handshake: true,
  })
);

app.set('socketio', io);

app.use(cors());
app.use(express.static("public"));
app.use(bodyParser.json());

app.get("/", async (req, res) => {
  //send angular app
});

app.use("/v1/run", commandRoutes);
app.use("/v1/auth", authRoutes);

server.listen(PORT, HOST);
console.log(`Running on http://${HOST}:${PORT}`);
