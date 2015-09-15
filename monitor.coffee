redis = require("redis")
Client = require("ssh2").Client
yaml = require("yaml")
fs = require("fs")
argv = require("yargs").argv

ssh_client = (cmd, credentials, line_cb) ->

  conn = new Client();

  conn.on "ready", ->
    conn.exec cmd, (err, stream) ->
      if err
        throw err

      got_line = (line) ->
        line_cb(line)

      rcvd_data = null
      stream.on "data", (data) ->
        packet = data.toString("utf8")
        for p in packet
          if rcvd_data is null
            rcvd_data = p
          else
            rcvd_data += p
          if p is "\n"
            got_line rcvd_data
            rcvd_data = null

      .on "close", (code, signal) ->
        console.log("Connection closed with #{signal} and #{code}")
      .stderr.on "data", (data) ->
        console.log "STDERR: #{data}"
  .connect credentials

if argv.config is undefined
  console.error("No Config provided for --config")
  process.exit(1)

console.log "Reading configuration file: #{argv.config}"
config_buffer = fs.readFileSync(argv.config)
config_obj = yaml.eval(config_buffer.toString("utf8"))
console.log "Will use #{config_obj.sshCredentials.user}@#{config_obj.sshCredentials.host}:#{config_obj.sshCredentials.port}"
credentials = config_obj.sshCredentials

mikrotik_line_to_dict = (line) ->

  line_dict = {}

  line_dict.id = line.match(/(\d+)/)[0]

  keys = line.match(/([a-z-]+)=/g).map (_key) ->
    return _key.split("=")[0]

  keys_generator = () ->
    for k in keys
      yield k
    return

  key_iterator = keys_generator()
  key = key_iterator.next().value
  until key is undefined
    next  = key_iterator.next().value
    if next isnt undefined
      value = line.match(new RegExp("#{key}=(.+) #{next}="))
      if value isnt null
        line_dict[key.replace(/-/g, "_")] = value[1].trim()
      key = next
    else
      value = line.match(new RegExp("#{key}=(.+)"))
      if value isnt null
        line_dict[key.replace(/-/g, "_")] = value[1].trim()
      key = undefined
  return line_dict

redis_client = redis.createClient()
gw_statuses = {}
# monitoring routes
ssh_client "/ip route print interval=1 without-paging terse", credentials, (line) ->
  if line.length > 2
    try
      line_dict = mikrotik_line_to_dict(line)
      if line_dict.gateway_status isnt undefined
        if gw_statuses[line_dict.gateway] isnt line_dict.gateway_status
          redis_client.set("gw_"+line_dict.gateway, line_dict.gateway_status)
          gw_statuses[line_dict.gateway] = line_dict.gateway_status
          redis_client.publish("monitoring", "gw:#{line_dict.gateway}:#{line_dict.gateway_status}")
      redis_client.sadd("gateways", line_dict.gateway)
      if line_dict.routing_mark?
        redis_client.sadd("routing_marks", line_dict.routing_mark)
    catch e
      console.log("Error: #{e} '#{line}'")
      throw e


routing_marks = {}
# monitoring mangles
ssh_client "/ip firewall mangle print interval=1 without-paging terse", credentials, (line) ->
  if line.length > 2
    try
      line_dict = mikrotik_line_to_dict(line)
      if line_dict.action is "mark-routing"
        if routing_marks[line_dict.src_address] isnt line_dict.new_routing_mark
          routing_marks[line_dict.src_address] = line_dict.new_routing_mark
          redis_client.set("srm_"+line_dict.src_address, JSON.stringify(line_dict))
          redis_client.publish("monitoring", "srm:#{line_dict.src_address}:#{line_dict.new_routing_mark}")
          redis_client.sadd("marked_subnets", line_dict.src_address)
    catch e
      console.log("Error: #{e} '#{line}'")
      throw e

console.log("Monitoring on.")
