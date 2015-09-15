var app = require("express.io")()
var redis = require("redis")
var naturalsort = require("naturalsort")
var yaml = require("yaml")
var argv = require("yargs").argv
var fs = require("fs")
var Client = require("ssh2").Client
var _ = require("lodash")

var router = app
redis_client = redis.createClient()

router.get("/gateway", function(req, res) {
  redis_client.smembers("gateways", function(err, reply) {
    reply.sort()
    res.json(reply)
  })
});

router.get("/gateway/:gateway_name", function(req, res) {
  var gw_name = req.params.gateway_name
  redis_client.get("gw_"+gw_name, function(err, reply) {
    res.json({"gateway": gw_name, "status": reply})
  });
})

router.get("/routing_marks", function(req, res) {
  redis_client.smembers("routing_marks", function(err, reply) {
    res.json(reply)
  });
});

router.get("/subnet", function(req, res) {
  redis_client.smembers("marked_subnets", function(err, reply) {
    var subnets = _.sortBy(reply, function(val) {
      return parseInt(_.words(val, /\d+/g)[2]);
    })
    res.json(subnets)
  });
});

router.get("/subnet/:subnet", function(req, res) {
  var subnet = req.params.subnet.replace("-", "/")
  redis_client.get("srm_"+subnet, function(err, reply) {
    subnet_obj = JSON.parse(reply)
    res.json({"subnet": subnet_obj.src_address, "routing_mark": subnet_obj.new_routing_mark})
  });
})


var change_routing_mark = function(subnet, routing_mark, cb) {
  fs.readFile(argv.config, function(err, config_buffer) {
    config = yaml.eval(config_buffer.toString("utf8"));
    redis_client.get("srm_"+subnet, function(err, reply) {
      reply = JSON.parse(reply)
      config = yaml.eval(config_buffer.toString())
      conn = new Client();
      conn.on('ready', function() {
        conn.exec("ip firewall mangle set " + reply.id + " new-routing-mark=\"" + routing_mark + "\"", function(err, stream) {
          if (err) {
            console.error(err);
            conn.end()
          }
          stream.on("close", function(err, sig) {
            cb()
            conn.end()
            if (err) console.error(err);
          });
        });
      }).connect(config.sshCredentials);

    });

  })
};

router.post("/subnet/:subnet", function(req, res) {
  var subnet = req.params.subnet.replace("-", "/");
  if (req.body.routing_mark !== undefined) {
    change_routing_mark(subnet, req.body.routing_mark, function() {
      res.send(true)
    })
  }

})

module.exports = router
