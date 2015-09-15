
var express = require("express.io")



channel = {
  "subscribe": function(req) {
    req.io.join("monitoring")
  }
}

module.exports = channel
