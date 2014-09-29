require 'socket'
require 'timeout'

After do
  @socket.nil? || @socket.close
  unless @mqtt.nil?
    Process.kill('INT', @mqtt.pid)
    Process.wait(@mqtt.pid)
  end
end

def connect_to_broker_tcp(port = 1883)
  @mqtt = IO.popen('dist/build/mqtt_hs/mqtt_hs')
  Timeout.timeout(1) do
    while @socket.nil?
      begin
        @socket = TCPSocket.new('localhost', port)
      rescue Errno::ECONNREFUSED
        # keep trying until the server is up or we time out
      end
    end
  end
end

def send_bytes(bytes)
  @socket.sendmsg(bytes.pack('C*'))
end

def send_mqtt_connect
  send_bytes [0x10, 0x2a, # fixed header
              0x00, 0x06] + 'MQIsdp'.unpack('C*') + \
             [0x03, # protocol version
              0xcc, # connection flags 1100111x user, pw, !wr, w(01), w, !c, x
              0x00, 0x0a, # keepalive of 10
              0x00, 0x03, 'c'.ord, 'i'.ord, 'd'.ord, # client ID
              0x00, 0x04, 'w'.ord, 'i'.ord, 'l'.ord, 'l'.ord, # will topic
              0x00, 0x04, 'w'.ord, 'm'.ord, 's'.ord, 'g'.ord, # will msg
              0x00, 0x07, 'g'.ord, 'l'.ord, 'i'.ord, 'f'.ord, 't'.ord, 'e'.ord, 'l'.ord, # username
              0x00, 0x02, 'p'.ord, 'w'.ord, # password
             ]
end

Given(/^I have established a TCP connection to the broker on port (\d+)$/) do |port|
  connect_to_broker_tcp(port)
end

When(/^I send a CONNECT MQTT message$/) do
  send_mqtt_connect
end

def assert_recv(bytes)
  @socket.recv(bytes.length).unpack('C*').should == bytes
end

def expect_mqtt_connack
  assert_recv [0x20, 0x2, 0x0, 0x0]
end

Then(/^I should receive a CONNACK MQTT message$/) do
  expect_mqtt_connack
end

def connect_to_broker_mqtt(port)
  connect_to_broker_tcp(port)
  send_mqtt_connect
  expect_mqtt_connack
end

Given(/^I have connected to the broker on port (\d+)$/) do |port|
  connect_to_broker_mqtt(port)
end

When(/^I subscribe to one topic with msgId (\d+)$/) do |msgId|
  send_bytes [0x82, 10, # fixed header
              0x00, msgId.to_i, # message ID
              0x00, 0x05, 'f'.ord, 'i'.ord, 'r'.ord, 's'.ord, 't'.ord,
              0x01, # qos
             ]
end

Then(/^I should receive a SUBACK message with qos (\d+) and msgId (\d+)$/) do |qos, msgId|
  assert_recv [0x90, 3, 0, msgId.to_i, qos.to_i]
end
