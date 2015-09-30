For this example set up a corresponding call controller, view, template, and channel. This call channel will faciliate message passing between the clients.

```javascript
import socket from "./socket"

let channel = socket.channel("call", {})
channel.join()
  .receive("ok", () => { console.log("Successfully joined call channel") })
  .receive("error", () => { console.log("Unable to join") })
```

Before getting started add the following line to ``web/templates/layout/app.html.eex`` to enable the WebRTC code to work across different browsers.

```html
<script src="//cdn.temasys.com.sg/adapterjs/0.10.x/adapter.debug.js"></script>
```
Next add video elments to the template.

```html
  <video id=“localVideo" autoplay></video>
  <video id=“remoteVideo" autoplay></video>

  <button id=“connect”>Connect</button>
  <button id="call">Call</button>
  <button id="hangup">Hangup</button>
```

And wire up the buttons.

```javascript
let localStream, peerConnection;
let localVideo = document.getElementById('localVideo');
let remoteVideo = document.getElementById('remoteVideo');
let connectButton = document.getElementById("connect");
let callButton = document.getElementById("call");
let hangupButton = document.getElementById("hangup");

hangupButton.disabled = true;
callButton.disabled = true;
connectButton.onclick = connect;
callButton.onclick = call;
hangupButton.onclick = hangup;
```

Then begin to define how clients will establish their connections.

```javascript
function connect() {
  console.log("Requesting local stream");
  navigator.getUserMedia({audio:true, video:true}, gotStream, error => {
       console.log("getUserMedia error: ", error);
   });
}
```

Here the getUserMedia function captures the local video stream and then calls the callback function gotStream.

```javascript
function gotStream(stream) {
   console.log("Received local stream");
   localVideo.src = URL.createObjectURL(stream);
   localStream = stream;
   setupPeerConnection();
}
```

gotStream sets the local stream and then calls setupPeerConnection.

```javascript
function setupPeerConnection() {
  connectButton.disabled = true;
  callButton.disabled = false;
  hangupButton.disabled = false;
  console.log("Waiting for call");

  let servers = {
    'iceServers': [{
      'url': 'stun:stun.example.org'
    }]
  };

  peerConnection = new RTCPeerConnection(servers);
  console.log("Created local peer connection");
  peerConnection.onicecandidate = gotLocalIceCandidate;
  peerConnection.onaddstream = gotRemoteStream;
  peerConnection.addStream(localStream);
  console.log("Added localStream to localPeerConnection");
}
```

setUpPeerConnection creates a new RTCPeerConnection and then sets callbacks for when certain events occur on the connection, such as an ICE candidate is detected or a stream is added. Then add the local video stream to the peer connection.

Next add the call function to send a message to other clients connected on the channel with a local peer connection.

```javascript
function call() {
  callButton.disabled = true;
  console.log("Starting call");
  peerConnection.createOffer(gotLocalDescription, handleError);
}
```

The createOffer function is being passed the following gotLocalDescription callback.

```javascript
function gotLocalDescription(description){
  peerConnection.setLocalDescription(description, () => {
      channel.push("message", { body: JSON.stringify({
              'sdp': peerConnection.localDescription
          })});
      }, handleError);
  console.log("Offer from localPeerConnection: \n" + description.sdp);
}
```

The createOffer function created a description of the local peer connection and then sent that description to any potential clients. Once a client receives such a description it then calls the following gotRemoteDescription function.

```javascript
function gotRemoteDescription(description){
  console.log("Answer from remotePeerConnection: \n" + description.sdp);
  peerConnection.setRemoteDescription(new RTCSessionDescription(description.sdp));
  peerConnection.createAnswer(gotLocalDescription, handleError);
}
```

Here it sets the remote description on its local peer connection so it can connect to that remote client. It then replies with an answer containing its own description so that remote client can connect back to it as well.

The descriptions being sent back and forth between the clients also contain the streams that were added to their peer connections. Once a client receives a remote stream it will call the following function.

```javascript
function gotRemoteStream(event) {
  remoteVideo.src = URL.createObjectURL(event.stream);
  console.log("Received remote stream");
}
```

Here the remote stream is being set to the video element in the template.

Also, when the local description is created it also creates a local ICE candidate, which will call the following function.

```javascript
function gotLocalIceCandidate(event) {
  if (event.candidate) {
    console.log("Local ICE candidate: \n" + event.candidate.candidate);
    channel.push("message", {body: JSON.stringify({
        'candidate': event.candidate
    })});
  }
}
```

This sends information about the local ICE candidate over the channel to any potential clients. When a client receives a description about an ICE candidate it will call the following function.

```javascript
function gotRemoteIceCandidate(event) {
  callButton.disabled = true;
  if (event.candidate) {
    peerConnection.addIceCandidate(new RTCIceCandidate(event.candidate));
    console.log("Remote ICE candidate: \n " + event.candidate.candidate);
  }
}
```

This function will add information about the remote candidate to its local peer connection.

When the channel receives a message from the server it needs to know how to process that message. If the message it receives is a description of the remote peer connection it needs to call the gotRemoteDescription function, but if it is a description of the remote ICE candidate it needs to call the gotRemoteIceCandidate function. Implement the channel’s event handler to account for these two scenarios.

```javascript
channel.on("message", payload => {
  let message = JSON.parse(payload.body);
  if (message.sdp) {
    gotRemoteDescription(message);
  } else {
    gotRemoteIceCandidate(message);
  }
})
```

Also include a hangup function so a user can close the connection and stop the video chat session.

```javascript
function hangup() {
  console.log("Ending call");
  peerConnection.close();
  localVideo.src = null;
  peerConnection = null;
  hangupButton.disabled = true;
  connectButton.disabled = false;
  callButton.disabled = true;
}
```

And finally add the handleError function.

```javascript
function handleError(error) {
  console.log(error.name + ': ' + error.message);
}
```

For this example implementation to work in the browser, open up two tabs and click the connect button in each one. You should see that each tab has created a local peer connection and added its local video stream. If you click the call button from one of the tabs then it will send a description of its local peer connection to the other peer connection, and after they exchange the necessary information they will establish their remote connection, beginning the chat session.
