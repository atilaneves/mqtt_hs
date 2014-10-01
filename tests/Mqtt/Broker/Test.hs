module Mqtt.Broker.Test (testConnack, testSuback) where

import Test.Framework (testGroup)
import Test.Framework.Providers.HUnit
import Test.HUnit
import Data.ByteString.Lazy (pack)
import Data.Char (ord)
import Data.Word (Word8)
import Mqtt.Broker (getReplies, getMessageType, Reply)

testConnack = testGroup "Connect" [ testCase "Test MQTT reply includes CONNACK" test_decode_mqtt_connect,
                                    testCase "Test getting message type" test_get_message_type]


-- Helper to transform a character into a byte
char :: Char -> Word8
char x = (fromIntegral $ ord x) :: Word8


-- Test that message types are returned correctly from a byte string
test_get_message_type :: Assertion
test_get_message_type = do
  getMessageType (pack [0x10, 0x2a]) @?= 1
  getMessageType (pack [0x20, 0x2a]) @?= 2

-- Test that we get a MQTT CONNACK in reply to a CONNECT message
test_decode_mqtt_connect :: Assertion
test_decode_mqtt_connect = getReplies 3 request [] @?= ([(3, pack [32, 2, 0, 0])] :: [Reply Integer])
                           where request = pack $ [0x10, 0x2a, -- fixed header
                                                   0x00, 0x06] ++
                                          [char 'M', char 'Q', char 'I', char 's', char 'd', char 'p'] ++
                                          [0x03, -- protocol version
                                           0xcc, -- connection flags 1100111x user, pw, !wr, w(01), w, !c, x
                                           0x00, 0x0a, -- keepalive of 10
                                           0x00, 0x03, char 'c', char 'i', char 'd', -- client ID
                                           0x00, 0x04, char 'w', char 'i', char 'l', char 'l', -- will topic
                                           0x00, 0x04, char 'w', char 'm', char 's', char 'g', -- will msg
                                           0x00, 0x07,
                                           char 'g', char 'l', char 'i', char 'f', char 't', char 'e', char 'l', --username
                                           0x00, 0x02, char 'p', char 'w'] --password
                                                                           -- replies = Mqtt.Broker.getReplies request



testSuback = testGroup "Subscribe" [ testCase "MQTT reply to 2 topic subscribe message" testSubackTwoTopics,
                                     testCase "MQTT reply to 1 topic subscribe message" testSubackOneTopic]
testSubackTwoTopics :: Assertion
testSubackTwoTopics = getReplies 4 request [] @?= ([(4, pack [0x90, 0x04, 0x00, 0x21, 0, 0])] :: [Reply Integer])
                    where request = pack $ [0x8c, 0x10, -- fixed header
                                            0x00, 0x21, -- message ID
                                            0x00, 0x05, char 'f', char 'i', char 'r', char 's', char 't',
                                            0x01, -- qos
                                            0x00, 0x03, char 'f', char 'o', char 'o',
                                            0x02 -- qos
                                            ]

testSubackOneTopic :: Assertion
testSubackOneTopic = getReplies 7 request [] @?= ([(7, pack [0x90, 0x03, 0x00, 0x33, 0])] :: [Reply Integer])
                     where request = pack $ [0x8c, 10, -- fixed header
                                             0, 0x33, -- message ID
                                             0, 5, char 'f', char 'i', char 'r', char 's', char 't',
                                             0x01 -- qos
                                             ]
