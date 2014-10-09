#!/bin/env ruby

require 'socket'
require 'timeout'

def send_bytes(bytes)
  $socket.sendmsg(bytes.pack('C*'))
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

def send_mqtt_subscribe
  msg_id = 42
  send_bytes [0x8c, 10, # fixed header
              0, msg_id.to_i, # message ID
              0, 5, 'f'.ord, 'i'.ord, 'r'.ord, 's'.ord, 't'.ord,
              0x01, # qos
             ]
end

def assert_recv(bytes)
  recvd = $socket.recv(bytes.length).unpack('C*')
  fail "Oops: Got #{recvd} instead of #{bytes}" unless recvd == bytes
end

def expect_mqtt_connack
  assert_recv [0x20, 0x2, 0x0, 0x0]
end

def connect_to_broker_tcp(port = 1883)
  puts 'starting binary'
  $mqtt = IO.popen('dist/build/mqtt_hs/mqtt_hs')
  puts "pid of binary: #{$mqtt.pid}"
  Timeout.timeout(1) do
    while $socket.nil?
      begin
        $socket = TCPSocket.new('localhost', port)
      rescue Errno::ECONNREFUSED
        # keep trying until the server is up or we time out
      end
    end
  end
end


port = 1883
connect_to_broker_tcp(port)
puts 'Connected to the broker on TCP 1883'

puts 'Sending MQTT connect'
send_mqtt_connect
puts 'MQTT connect sent'
puts 'Expecting connack'
expect_mqtt_connack
puts 'Got connack'
puts 'Sending subscribe'
send_mqtt_subscribe
puts 'Subscribe sent'
puts 'Expecting suback'
assert_recv [0x90, 3, 0, 42, 0]
puts 'Suback recvd'


$socket.nil? || $socket.close
unless $mqtt.nil?
  puts "Killing mqtt with pid #{$mqtt.pid}"
  Process.kill('QUIT', $mqtt.pid)
  puts 'Waiting for process to exit'
  Process.wait($mqtt.pid)
  puts 'Wait is over'
end
