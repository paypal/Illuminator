
require 'rubygems'
require 'json'
require 'base64'
require 'dnssd'
require 'socket'
require 'timeout'
require 'optparse'

# all parsing code goes here
def parse_arguments(args)
  ret = {}
  ret["timeout"] = 15
  op = OptionParser.new do |opts|
    opts.banner = "Usage: #{__FILE__} [options]"
    opts.separator ""
    opts.separator "Specific options:"

    opts.on("-a", "--argument=[JSON]",
            "Pass the supplied JSON data over the bridge") do |v|
      ret["argument"] = v
    end

    opts.on("-b", "--b64argument=[B64-JSON]",
            "Pass the base64-encoded JSON data over the bridge") do |v|
      ret["b64argument"] = v
    end

    opts.on("-s", "--selector=SELECTOR",
            "Call the given function (selector) via the bridge") do |v|
      ret["selector"] = v
    end

    opts.on("-c", "--callUID=UID",
            "Use the given UID to properly identify the return value of this call") do |v|
      ret["callUID"] = v
    end

    opts.on("-r", "--hardwareID=[HARDWAREID]",
            "If provided, connect to the physical iOS device with this hardware ID instead of a simulator") do |v|
      ret["hardwareID"] = v
    end

    opts.on("-t", "--timeout=[TIMEOUT]",
            "The timeout in seconds for reading a response from the bridge (default 15)") do |v|
      ret["timeout"] = v.to_i
    end

    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end

  end
  op.parse!(args)
  return ret
end


# communicate the result to the console
# success: boolean whether it all went well
# failmsg: what to say went wrong
# checkpoints: some stuff to print out, debug info
# outputData: the actual results
def print_result_and_exit(success, failmsg, checkpoints, response=nil)
  outputData = {}
  outputData["checkpoints"] = checkpoints
  outputData["response"] = response unless response.nil?
  outputData["success"] = success
  outputData["message"] = failmsg
  puts JSON.pretty_generate(outputData)
  exit(success ? 0 : 1)
end


def get_host_port_of_hardwareID(hardwareID, timeout_seconds)
  service = DNSSD::Service.new
  host, port = nil, nil
  begin
    Timeout::timeout(timeout_seconds) do
      service.browse '_bridge._tcp' do |result|
        if result.name.eql? "UIAutomationBridge_#{hardwareID}"
          resolver = DNSSD::Service.new
          resolver.resolve result do |r|
            host = r.target
            port = r.port
            break unless r.flags.more_coming?
          end
          break
        end
      end
      return host, port
    end
  rescue Timeout::Error
  end
  return host, port
end


def connect(host, port, timeout=5)
  addr = Socket.getaddrinfo(host, nil)
  sock = Socket.new(Socket.const_get(addr[0][0]), Socket::SOCK_STREAM, 0)

  if timeout
    secs = Integer(timeout)
    usecs = Integer((timeout - secs) * 1_000_000)
    optval = [secs, usecs].pack('l_2')
    sock.setsockopt Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, optval
    sock.setsockopt Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, optval
  end
  begin
    sock.connect(Socket.pack_sockaddr_in(port, addr[0][3]))
    return sock, ""
  rescue Exception => e
    return nil, "Failed to connect to #{host}:#{port} - #{e.class.name} - #{e.message}"
  end
end


# these describe what we expect to have happen, and we will check them off as they do
checkpoints = {}
checkpoints["ruby"] = true
checkpoints["argument"] = nil
checkpoints["hardwareID"] = nil
checkpoints["connection"] = nil
checkpoints["request"] = nil
checkpoints["response"] = nil
checkpoints["callUIDMatch"] = nil


# process the input
options = parse_arguments(ARGV)

# verify that the input selector was provided
if options["selector"].nil?
    print_result_and_exit(false, "selector not provided", checkpoints)
end

# decode b64 argument if provided
unless options["b64argument"].nil?
  begin
    decoded_arg = Base64.strict_decode64(options["b64argument"])
    options['argument'] = decoded_arg # the next if block will find & process this
    JSON.parse(decoded_arg)
  rescue ArgumentError => e
    print_result_and_exit(false, "Error decoding b64argument: #{e.message}", checkpoints)
  rescue JSON::ParserError => e
    print_result_and_exit(false, "Decoded b64argument does not appear to contain (valid) JSON", checkpoints)
  end
end

# parse JSON in argument if provided (or b64 provided)
unless options["argument"].nil?
  checkpoints["argument"] = false
  begin
    parsed_arg = JSON.parse(options["argument"])
    options["jsonArgument"] = parsed_arg
    checkpoints["argument"] = true
  rescue JSON::ParserError => e
    print_result_and_exit(false, "Error parsing JSON argument: #{e.message}", checkpoints)
  end
end

# build the request that will go the server
requestHash = {}
requestHash['argument'] = options["jsonArgument"] unless options["jsonArgument"].nil?
requestHash["selector"] = options["selector"]
requestHash["callUID"] = options["callUID"]
request = requestHash.to_json


# get the host/port according to whether we are using hardware
host, port = '127.0.0.1', 4200
unless options["hardwareID"].nil?
  checkpoints["hardwareID"] = false
  host, port = get_host_port_of_hardwareID(options["hardwareID"], 3)
  if host.nil? or port.nil?
    print_result_and_exit(false, "Failed to get host/port for hardware ID", checkpoints)
  end
  checkpoints["hardwareID"] = true
end

# connect
checkpoints["connection"] = false
socketStream, errMessage = connect host, port
if socketStream.nil?
    print_result_and_exit(false, errMessage, checkpoints)
end
checkpoints["connection"] = true

begin
  # send request
  checkpoints["request"] = false
  socketStream.write(request)
  checkpoints["request"] = true

  # read response
  checkpoints["response"] = false
  response = ''
  
	timeout(options["timeout"]) do
	  while true
	    char = nil
	    char = socketStream.getc
		break if char.nil?
	    response = response + char
	    begin 
			#TODO fix crazy parsing each character
			JSON.parse(response)
			break
		rescue
			# nothing
		end
	  end
	end
  checkpoints["response"] = true

rescue Timeout::Error
  print_result_and_exit(false, "Timed out waiting for response", checkpoints)
rescue Exception => e
  print_result_and_exit(false, "Error while waiting for response: #{e.inspect()}", checkpoints)
ensure
  socketStream.close
end

resp = JSON.parse(response)

# check callUID
checkpoints["callUIDMatch"] = false
if options["callUID"] != resp["callUID"]
  print_result_and_exit(false, "Expected callUID=#{options["callUID"]} but got callUID=#{resp["callUID"]}", checkpoints, resp)
end
checkpoints["callUIDMatch"] = true

print_result_and_exit(true, "all bridge options completed successfully", checkpoints, resp)
