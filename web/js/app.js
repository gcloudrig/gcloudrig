
var your_jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6InRlc3QiLCJpYXQiOjE2MTMzNTMxNDd9.FD03-ErudZ0qsvIMs4FTEa80m2wWdd8en1xmIrdoCVw';

var socket = io('http://localhost:5000', {
    extraHeaders: { Authorization: `Bearer ${your_jwt}` }
  });

socket.on("process_data", (msg) => {
  console.log(msg);
});
