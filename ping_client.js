var WebSocket = require('ws');
var ws = new WebSocket('ws://localhost:8888');

ws.on('open', function() {
        console.log("Got a connection!");
        ws.ping();
});

ws.on('close', function() {
        console.log('disconnected');
});

ws.on('error', function(error) {
        console.dir(error);
});

ws.on('message', function(data, flags) {
       console.dir(flags);
       console.dir(data); 
       ws.close();
});

ws.on('pong', function(data, flags) {
      console.dir(flags);
      console.dir(data); 
});
