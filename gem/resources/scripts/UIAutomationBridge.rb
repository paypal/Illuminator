require 'bundler/setup'
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

    opts.on("-p", "--plaintext",
            "Whether to print the output in plain (JSON) text, instead of base-64") do |v|
      ret["plaintext"] = v
    end

    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end

  end
  op.parse!(args)
  return ret
end


def get_host_port_of_hardware_id(hardware_id, timeout_seconds)
  service = DNSSD::Service.new
  host, port = nil, nil
  begin
    Timeout::timeout(timeout_seconds) do
      service.browse '_bridge._tcp' do |result|
        if result.name.eql? "UIAutomationBridge_#{hardware_id}"
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




class BridgeClient
  attr_accessor :options
  attr_accessor :plaintext
  attr_accessor :write_to_file
  attr_reader   :checkpoints

  def initialize(options)
    @options = options
    @plaintext = options["plaintext"] # this is a client option, so pull it out
    @log_to_file = false
    init_checkpoints
  end

  def init_checkpoints
    # these describe what we expect to have happen, and we will check them off as they do
    @checkpoints = {}
    @checkpoints["ruby"] = true
    @checkpoints["argument"] = nil
    @checkpoints["hardwareID"] = nil
    @checkpoints["connection"] = nil
    @checkpoints["request"] = nil
    @checkpoints["response"] = nil
    @checkpoints["callUIDMatch"] = nil
  end

  # communicate the result to the console
  # success: boolean whether it all went well
  # failmsg: what to say went wrong
  # checkpoints: some stuff to print out, debug info
  # output_data: the actual results
  def finish(success, failmsg, response=nil)
    output_data = {}
    output_data["checkpoints"] = @checkpoints
    output_data["response"] = response unless response.nil?
    output_data["success"] = success
    output_data["message"] = failmsg
    output_str = JSON.pretty_generate(output_data)

    if @log_to_file
      File.open('last_bridge_output.txt', "w") { |f| f.write(output_str) }
    end

    if @plaintext
      puts output_str
    else
      puts Base64.strict_encode64(output_str)
    end
    exit(success ? 0 : 1)
  end

  def validate_options
    # verify that the input selector was provided
    if @options["selector"].nil?
      finish(false, "selector not provided")
    end

    check_arguments
  end

  # decode b64 argument if provided
  # side effect: load it into the "argument" option, overwriting whatever was there.
  #              (it's undefined behavior to supply both b64 and non-b64 args)
  def check_b64_arguments
    unless @options["b64argument"].nil?
      begin
        decoded_arg = Base64.strict_decode64(@options["b64argument"])
        @options['argument'] = decoded_arg # the next if block will find & process this
        JSON.parse(decoded_arg)
      rescue ArgumentError => e
        finish(false, "Error decoding b64argument: #{e.message}")
      rescue JSON::ParserError => e
        finish(false, "Decoded b64argument does not appear to contain (valid) JSON")
      end
    end
  end

  # validate plain text JSON argument
  def check_arguments
    check_b64_arguments

    unless @options["argument"].nil?
      @checkpoints["argument"] = false
      begin
        parsed_arg = JSON.parse(options["argument"])
        @options["jsonArgument"] = parsed_arg
        @checkpoints["argument"] = true
      rescue JSON::ParserError => e
        finish(false, "Error parsing JSON argument: #{e.message}")
      end
    end
  end

  # check the endpoint we're trying to hit, and return host/port
  def check_endpoint
    # get the host/port according to whether we are using hardware
    host, port = '127.0.0.1', 4200
    unless @options["hardwareID"].nil?
      @checkpoints["hardwareID"] = false
      host, port = get_host_port_of_hardware_id(options["hardwareID"], 3)
      if host.nil? or port.nil?
        finish(false, "Failed to get host/port for hardware ID")
      end
      @checkpoints["hardwareID"] = true
    end
    @checkpoints["host"] = host
    @checkpoints["port"] = port
  end

  # try to connect, and return the connection object
  def check_connection

    # connect
    @checkpoints["connection"] = false
    socket_stream, err_message = connect(@checkpoints["host"], @checkpoints["port"])
    if socket_stream.nil?
      finish(false, err_message)
    end
    @checkpoints["connection"] = true
    socket_stream
  end

  # validate that the callUID we got back matches the one we sent
  def check_call_uid(response)
    @checkpoints["callUIDMatch"] = false
    if @options["callUID"] != response["callUID"]
      finish(false, "Expected callUID=#{options["callUID"]} but got callUID=#{response["callUID"]}", response)
    end
    @checkpoints["callUIDMatch"] = true
  end

  # build the request that will go the server
  def build_request_json
    request_hash = {}
    request_hash['argument'] = @options["jsonArgument"] unless @options["jsonArgument"].nil?
    request_hash["selector"] = @options["selector"]
    request_hash["callUID"] = @options["callUID"]
    request = request_hash.to_json
    @checkpoints["actual_request"] = request_hash
    request
  end

  def process_request
    check_endpoint # loads host/port
    socket_stream = check_connection

    begin
      # send request
      @checkpoints["request"] = false
      socket_stream.write(build_request_json)
      @checkpoints["request"] = true

      # read response
      @checkpoints["response"] = false
      raw_response = ''

      timeout(@options["timeout"]) do
        loop do
          new_data = nil
          begin
            timeout(0.1) { new_data = socket_stream.gets("}") } # read up to closing brace at a time
          rescue Timeout::Error # no big deal here
          end

          raw_response = raw_response + new_data unless new_data.nil?

          # successfully parse, or go back and try again
          begin
            JSON.parse(raw_response)
            break
          rescue
          end

        end
      end
      @checkpoints["response"] = true
      @checkpoints["response_length"] = raw_response.length

    rescue Timeout::Error
      finish(false, "Timed out waiting for response")
    rescue Exception => e
      finish(false, "Error while waiting for response: #{e.inspect()}")
    ensure
      socket_stream.close
    end

    response = JSON.parse(raw_response)

    check_call_uid(response)

    finish(true, "all bridge options completed successfully", response)

  end

end

# process the input
options = parse_arguments(ARGV)

# create the bridge client and go
bc = BridgeClient.new(options)
# bo.log_to_file = false
bc.validate_options
bc.process_request
