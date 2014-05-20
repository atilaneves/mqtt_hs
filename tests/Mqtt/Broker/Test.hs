module Mqtt.Broker.Test (testConnack) where

import Test.Framework (testGroup)
import Test.Framework.Providers.HUnit
import Test.HUnit
import Data.ByteString.Lazy (uncons, pack, unpack)
import Data.Char (ord)
import Data.Word (Word8)

testConnack = testGroup "Encoding" [ testCase "Test MQTT reply includes CONNACK" test_decode_mqtt_connect]


char :: Char -> Word8
char x = (fromIntegral $ ord x) :: Word8



test_decode_mqtt_connect :: Assertion
test_decode_mqtt_connect = (unpack (request)) @?= ([1, 2] :: [Word8])
                           where request = pack $ [0x10, 0x2a, -- fixed header
                                                        0x00, 0x06] ++
                                          [char 'M', char 'Q', char 'I', char 's', char 'd', char 'p']++
                                          [0x03, -- protocol version
                                           0xcc, -- connection flags 1100111x user, pw, !wr, w(01), w, !c, x
                                           0x00, 0x0a, -- keepalive of 10
                                           0x00, 0x03, char 'c', char 'i', char 'd', -- client ID
                                           0x00, 0x04, char 'w', char 'i', char 'l', char 'l', -- will topic
                                           0x00, 0x04, char 'w', char 'm', char 's', char 'g', -- will msg
                                           0x00, 0x07, char 'g', char 'l', char 'i', char 'f', char 't', char 'e', char 'l', --username
                                           0x00, 0x02, char 'p', char 'w'] --password
                                -- replies = Mqtt.Broker.getReplies request
