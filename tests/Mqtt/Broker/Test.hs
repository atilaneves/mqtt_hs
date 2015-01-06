module Mqtt.Broker.Test (testConnack
                        , testSuback
                        , testPublish
                        , testWildcards
                        , testPing) where

import Test.Framework (testGroup)
import Test.Framework.Providers.HUnit
import Test.HUnit
import Data.ByteString (pack)
import qualified Data.ByteString as BS
import Data.Char (ord)
import Data.Word (Word8)
import Mqtt.Broker (
                    handleRequest
                   , topicMatches
                   , serviceRequests
                   )


testConnack = testGroup "Connect" [ testCase "Test MQTT reply includes CONNACK" testDecodeMqttConnect
                                  ]


-- Helper to transform a character into a byte
char :: Char -> Word8
char x = (fromIntegral $ ord x) :: Word8


-- Test that we get a MQTT CONNACK in reply to a CONNECT message
testDecodeMqttConnect :: Assertion
testDecodeMqttConnect = handleRequest (3::Int) request [] @?= ([], [(3, pack [32, 2, 0, 0])])
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



testSuback = testGroup "Subscribe" [ testCase "MQTT reply to 2 topic subscribe message" testSubackTwoTopics
                                   , testCase "MQTT reply to 1 topic subscribe message" testSubackOneTopic
                                   , testCase "Test MQTT SUBACK reply for SUBSCRIBE" testGetSuback
                                   , testCase "Test subscribe" testSubscribe
                                   ]
testSubackTwoTopics :: Assertion
testSubackTwoTopics = handleRequest (4::Int) request [] @?= ([("first", 4), ("foo", 4)],
                                                             [(4, pack [0x90, 0x04, 0x00, 0x21, 0, 0])])
                    where request = pack $ [0x8c, 0x10, -- fixed header
                                            0x00, 0x21, -- message ID
                                            0x00, 0x05, char 'f', char 'i', char 'r', char 's', char 't',
                                            0x01, -- qos
                                            0x00, 0x03, char 'f', char 'o', char 'o',
                                            0x02 -- qos
                                            ]

testSubackOneTopic :: Assertion
testSubackOneTopic = handleRequest (7::Int) request [] @?= ([("first", 7)], [(7, pack [0x90, 0x03, 0x00, 0x33, 0])])
                     where request = pack $ [0x8c, 10, -- fixed header
                                             0, 0x33, -- message ID
                                             0, 5, char 'f', char 'i', char 'r', char 's', char 't',
                                             0x01 -- qos
                                             ]


testGetSuback :: Assertion
testGetSuback = do
   handleRequest (9::Int) (pack [0x8c, 6, 0, 7, 0, 1, char 'f', 2]) [] @?=
                     ([("f", 9)], [(9, pack $ [0x90, 3, 0, 7, 0])])
   handleRequest (11::Int) (pack [0x8c, 6, 0, 8, 0, 1, char 'g', 2]) [] @?=
                     ([("g", 11)], [(11, pack $ [0x90, 3, 0, 8, 0])])
   handleRequest (6::Int) (pack [0x8c, 11, 0, 13, 0, 1, char 'h', 1, 0, 2, char 'a', char 'b', 2]) [] @?=
                  ([("h", 6), ("ab", 6)], [(6, pack $ [0x90, 4, 0, 13, 0, 0])])


testSubscribe :: Assertion
testSubscribe = do
  handleRequest (9::Int) (pack [0x8c, 6, 0, 7, 0, 1, char 'f', 2]) [("thingie", 1)] @?=
                   ([("thingie", 1), ("f", 9)], [(9, pack $ [0x90, 3, 0, 7, 0])])
  handleRequest (9::Int) (pack [0x8c, 6, 0, 7, 0, 1, char 'f', 2]) [("foo", 1), ("bar", 2)] @?=
                   ([("foo", 1), ("bar", 2), ("f", 9)], [(9, pack $ [0x90, 3, 0, 7, 0])])
  handleRequest (9::Int) (pack [0x8c, 8, 0, 7, 0, 3, char 'f', char 'o', char 'o', 2]) [] @?=
                   ([("foo", 9)], [(9, pack $ [0x90, 3, 0, 7, 0])])


testPublish = testGroup "Publish" [ testCase "No msgs for no subs" testNoMsgWithNoSubs
                                  , testCase "One msg for exact sub" testOneMsgWithExactSub
                                  , testCase "One msg with wrong sub" testOneMsgWithWrongSub
                                  , testCase "One msg with two subs" testOneMsgWithTwoSubs
                                  , testCase "Another msg with exact sub" testAnotherMsgWithExactSub
                                  , testCase "Two clients" testTwoClients
                                  ]

strToBytes :: Num a => String -> [a]
strToBytes = map (fromIntegral . ord)

publishMsg :: BS.ByteString
publishMsg = pack $ [0x30, 5, 0, 3] ++ strToBytes "foo"

testNoMsgWithNoSubs :: Assertion
testNoMsgWithNoSubs = handleRequest (7::Int) publishMsg [] @?= ([], [])

testOneMsgWithExactSub :: Assertion
testOneMsgWithExactSub = handleRequest (4::Int) publishMsg [("foo", 4)] @?= ([("foo", 4)], [(4, publishMsg)])

testOneMsgWithWrongSub :: Assertion
testOneMsgWithWrongSub = handleRequest (3::Int) publishMsg [("bar", 2)] @?= ([("bar", 2)], [])

testOneMsgWithTwoSubs :: Assertion
testOneMsgWithTwoSubs = do
  handleRequest (1 :: Int) publishMsg [("foo", 1), ("bar", 2)] @?= ([("foo", 1), ("bar", 2)], [(1, publishMsg)])
  handleRequest (2 :: Int) publishMsg [("baz", 3), ("boo", 3)] @?= ([("baz", 3), ("boo", 3)], [])


testAnotherMsgWithExactSub :: Assertion
testAnotherMsgWithExactSub = do
  handleRequest (5 :: Int) myPublish [("/foo/bar", 5)] @?= ([("/foo/bar", 5)], [(5, myPublish)])
                where myPublish = pack $ [0x30, 16, 0, 8] ++
                                  strToBytes "/foo/bar" ++
                                  strToBytes "ohnoes"

testTwoClients :: Assertion
testTwoClients = do
  handleRequest (5 :: Int) myPublish subscriptions @?= (subscriptions, [(5, myPublish)])
                 where subscriptions = [("/foo/bar", 5), ("/bar/foo", 3)]
                       myPublish = pack $ [0x30, 16, 0, 8] ++
                                   strToBytes "/foo/bar" ++
                                   strToBytes "ohnoes"

testPing = testGroup "Ping" [ testCase "Ping" testPingImpl]

testPingImpl :: Assertion
testPingImpl = do
  handleRequest (3 :: Int) ping subscriptions @?= (subscriptions, [(3, pong)])
                where subscriptions = [("/path/to", 3)]
                      ping = pack [0xc0, 0]
                      pong = pack [0xd0, 0]

testWildcards = testGroup "Wildcards" [ testCase "Wildcard +" testWildcardPlus]

testWildcardPlus :: Assertion
testWildcardPlus = do
  topicMatches "foo/bar/baz" "foo/bar/baz" @?= True
  topicMatches "foo/bar" "foo/+" @?= True
  topicMatches "foo/baz" "foo/+" @?= True
  topicMatches "foo/bar/baz" "foo/+" @?= False
  topicMatches "foo/bar" "foo/#" @?= True
  topicMatches "foo/bar/baz" "bar/#" @?= False
  topicMatches "topics/bar/baz/boo" "topics/foo/#" @?= False
  topicMatches "foo/bar/baz" "foo/#" @?= True
  topicMatches "foo/bar/baz/boo" "foo/#" @?= True
  topicMatches "foo/bla/bar/baz/boo/bogadog" "foo/+/bar/baz/#" @?= True
  topicMatches "finance" "finance/#" @?= True
  topicMatches "finance" "finance#" @?= False
  topicMatches "finance" "#" @?= True
  topicMatches "finance/stock" "#" @?= True
  topicMatches "finance/stock" "finance/stock/ibm" @?= False
  topicMatches "topics/foo/bar" "topics/foo/#" @?= True
