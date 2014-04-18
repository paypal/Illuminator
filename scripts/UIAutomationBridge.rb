
# This must be
require 'rubygems'
require 'json'
require 'base64'
require 'dnssd'
require 'socket'

Dir.chdir(File.dirname(__FILE__) + "/../../")

argument = nil
hardwareID = nil
selector = ''
callUID = ''
expectsReturnValue = false;

ARGV.each do|parameter|
  argName, *rest = parameter.split('=' , 2)
  argValue = rest[0]
  if argName == '--argument'
    argument = argValue
  elsif argName == '--b64argument'
    argument = Base64.decode64(argValue)
  elsif argName == '--selector'
    selector = argValue
  elsif argName == '--callUID'
    callUID = argValue  
  elsif argName == '--hardwareID'
      hardwareID = argValue
  end
end

def connect(host, port, timeout=5)
  addr = Socket.getaddrinfo(host, nil)
  sock = Socket.new(Socket.const_get(addr[0][0]), Socket::SOCK_STREAM, 0)

  if timeout
    secs = Integer(timeout)
    usecs = Integer((timeout - secs) * 1_000_000)
    optval = [secs, usecs].pack("l_2")
    sock.setsockopt Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, optval
    sock.setsockopt Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, optval
  end
  sock.connect(Socket.pack_sockaddr_in(port, addr[0][3]))
  sock
end



resultHash = Hash.new
resultHash["selector"] = selector
resultHash["callUID"] = callUID
unless argument.nil?
  resultHash["argument"] = JSON.parse argument
end

result = resultHash.to_json

host = "127.0.0.1"
port = "4200"

unless hardwareID.nil?
  service = DNSSD::Service.new
  Timeout::timeout(1) do
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
  end
end 

outputJson = Hash.new
outputJson["ruby_check"] = true
outputJson["status_check"] = "initialized"

socketStream = connect host, port
socketStream.write(result)
response = ""
while line = socketStream.gets   
  response = response + line
end
socketStream.close

outputJson["response"] = JSON.parse response

print outputJson.to_json