require 'socket'
require 'timeout'
require 'rspec-expectations'

After do
  @socket.nil? || @socket.close
  unless @mqtt.nil?
    Process.kill('QUIT', @mqtt.pid)
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
              0x00, 0x02, 'p'.ord, 'w'.ord] # password
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

def subscribe(topic, msg_id, qos = 0)
  send_bytes [0x8c, 5 + topic.length, # fixed header
              0, msg_id, # message ID
              0, topic.length] + string_to_ints(topic)  + [qos]
end

When(/^I subscribe to one topic with msgId (\d+)$/) do |msg_id|
  subscribe('topic', msg_id.to_i)
end

def recv_suback(msg_id, qos = 0)
  assert_recv [0x90, 3, 0, msg_id.to_i, qos.to_i]
end

Then(/^I should receive a SUBACK message with qos (\d+) and msgId (\d+)$/) do |qos, msg_id|
  recv_suback(msg_id.to_i, qos.to_i)
end

When(/^I publish on topic "(.*?)" with payload "(.*?)"$/) do |topic, payload|
  remaining_length = topic.length + 2 + payload.length
  send_bytes [0x30, remaining_length, 0, topic.length] + \
    string_to_ints(topic) + string_to_ints(payload)
end

def string_to_ints(str)
  str.chars.map { |x| x.ord }
end

Then(/^I should not receive any messages$/) do
  expect do
    Timeout.timeout(1) do
      assert_recv []
    end
  end.to raise_error
end

msg_id = 1
When(/^I subscribe to topic "(.*?)"$/) do |topic|
  remaining_length = topic.length + 4
  qos = 1
  send_bytes [0x8c, remaining_length,
              0, msg_id,
              0, topic.length] + string_to_ints(topic) + [qos]
  msg_id += 1
end

Then(/^I should receive a message with topic "(.*?)" and payload "(.*?)"$/) do |topic, payload|
  Timeout.timeout(1) do
    remaining_length = topic.length + 2 + payload.length
    assert_recv [0x30, remaining_length, 0, topic.length] + \
      string_to_ints(topic) + string_to_ints(payload)
  end
end

When(/^I successfully subscribe to topic "(.*?)"$/) do |topic|
  subscribe(topic, msg_id)
  recv_suback(msg_id)
end
