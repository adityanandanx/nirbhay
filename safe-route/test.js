const accountSid = "AC5e40124b642394c6f353f176c00fa223";
const authToken = "f68abc66d8825528855e4c8c16d51304";
const client = require("twilio")(accountSid, authToken);

client.calls.create({
  url: "http://demo.twilio.com/docs/voice.xml",
  to: "+916387336115",
  from: "+19314130543",
})
.then(call => console.log(call.sid));