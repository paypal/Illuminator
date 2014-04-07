
# This must be
require 'rubygems'
require 'json'
require 'eventmachine'
require 'logger'
require 'base64'
require 'em-websocket-client'
require 'dnssd'

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
  elsif argName == '--expectsReturnValue'
    expectsReturnValue = true;
  end
end




resultHash = Hash.new
resultHash["selector"] = selector
resultHash["callUID"] = callUID
resultHash["expectsReturnValue"] = expectsReturnValue;
unless argument.nil?
  resultHash["argument"] = JSON.parse argument
end

result = resultHash.to_json


applicationAddress = "ws://localhost:4200"

unless hardwareID.nil?
  service = DNSSD::Service.new
  Timeout::timeout(1) do
      service.browse '_bridge._tcp' do |result|
      if result.name.eql? "UIAutomationBridge_#{hardwareID}"
        resolver = DNSSD::Service.new  
        resolver.resolve result do |r|  
         target = r.target  
         applicationAddress = "ws://#{r.target}:#{r.port}"
         break unless r.flags.more_coming?  
        end  
        break
      end
    end
  end
end 



def action
  perform_external_call
rescue Timeout::Error => e
  @error = e
  render :action => "error"
end

outputJson = Hash.new
outputJson["ruby_check"] = true
outputJson["status_check"] = "initialized"

#TODO: try/catch this and print out JSON regardless.
EM.run do
  # TODO: Add ability to send requests to the device.  This just sends to the simulator.
  conn = EventMachine::WebSocketClient.connect(applicationAddress)
  message = ""
  conn.callback do
    if (result.length > 0)
      conn.send_msg result
    end
  end

  conn.errback do |e|
    outputJson["status_check"] = "errbacked"
    outputJson["error_message"] = e
    puts "Got error: #{e}"
  end

  conn.stream do |msg|
    outputJson["status_check"] = "streamed"
    if msg.data == "done"
      outputJson["response"] = JSON.parse message
      conn.close_connection
    else
      message = message + msg.data
    end
  end

  conn.disconnect do
    EM::stop_event_loop
  end
end

print outputJson.to_json
