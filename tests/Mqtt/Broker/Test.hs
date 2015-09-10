module Mqtt.Broker.Test (testConnack
                        , testSuback
                        , testPublish
                        , testWildcards
                        , testDisconnect
                        , testPing
                        ) where

import Test.Framework (testGroup)
import Test.Framework.Providers.HUnit
import Test.HUnit
import Data.ByteString.Lazy (pack, empty)
import qualified Data.ByteString.Lazy as BS
import Data.Char (ord)
import Data.Word (Word8)
import Control.Monad.State.Lazy
import Mqtt.Broker (
                   topicMatches
                   , serviceRequest
                   , Response(CloseConnection, ClientMessages)
                   , Subscriptions
                   , unsubscribe
                   )


testDisconnect = testGroup "Disconnect"
                 [ testCase "No messages" testEmptyDisconnect
                 , testCase "One disconnect" testOnlyOneDisconnect
                 ]

testEmptyDisconnect :: Assertion
testEmptyDisconnect = serviceRequest handle empty subs @?= ClientMessages (subs, [])
                      where handle = 7 :: Int
                            subs = []

disconnectMsg :: BS.ByteString
disconnectMsg = pack [0xe0, 0] -- MQTT disconnect in bytes

testOnlyOneDisconnect :: Assertion
testOnlyOneDisconnect = serviceRequest handle disconnectMsg subs @?= CloseConnection
                        where handle = 5 :: Int
                              subs = []



testConnack = testGroup "Connect" [ testCase "Test MQTT reply includes CONNACK" testDecodeMqttConnect
                                  ]


-- Helper to transform a character into a byte
char :: Char -> Word8
char x = (fromIntegral $ ord x) :: Word8

connectMsg :: BS.ByteString
connectMsg = pack $ [0x10, 0x2a, -- fixed header
                     0x00, 0x06] ++
             [char 'M', char 'Q', char 'I', char 's', char 'd', char 'p'] ++
             [0x03, -- protocol version
              0xcc, -- connection flags 1100111x user, pw, !wr, w(01), w, !c, x
              0x00, 0x0a, -- keepalive of 10
              0x00, 0x03, char 'c', char 'i', char 'd', -- client ID
              0x00, 0x04, char 'w', char 'i', char 'l', char 'l', -- will topic
              0x00, 0x04, char 'w', char 'm', char 's', char 'g', -- will msg
              0x00, 0x07, -- size of username
              char 'g', char 'l', char 'i', char 'f', char 't', char 'e', char 'l', -- username
              0x00, 0x02, char 'p', char 'w'] --password


connackMsg :: BS.ByteString
connackMsg = pack [32, 2, 0, 0]


-- Test that we get a MQTT CONNACK in reply to a CONNECT message
testDecodeMqttConnect :: Assertion
testDecodeMqttConnect = serviceRequest handle connectMsg subs @?= ClientMessages ([(handle, connackMsg)], subs)
                           where handle = 3 :: Int
                                 subs = []



testSuback = testGroup "Subscribe" [ testCase "MQTT reply to 2 topic subscribe message" testSubackTwoTopics
                                   , testCase "MQTT reply to 1 topic subscribe message" testSubackOneTopic
                                   , testCase "Test MQTT SUBACK reply for SUBSCRIBE" testGetSuback
                                   , testCase "Test subscribe" testSubscribe
                                   , testCase "Test unsubscribe client" testUnsubscribeClient
                                   ]

subscribeTwoTopicsMsg :: BS.ByteString
subscribeTwoTopicsMsg = pack $ [0x8c, 0x10, -- fixed header
                                0x00, 0x21, -- message ID
                                0x00, 0x05, char 'f', char 'i', char 'r', char 's', char 't',
                                0x01, -- qos
                                0x00, 0x03, char 'f', char 'o', char 'o',
                                0x02 -- qos
                               ]

twoTopicSubs :: Int -> Subscriptions Int
twoTopicSubs handle = [("first", handle), ("foo", handle)]

twoTopicsResponse :: Int -> Response Int
twoTopicsResponse handle = ClientMessages ([(handle, pack [0x90, 0x04, 0x00, 0x21, 0, 0])],
                                           twoTopicSubs handle)

testSubackTwoTopics :: Assertion
testSubackTwoTopics = serviceRequest handle subscribeTwoTopicsMsg [] @?= twoTopicsResponse handle
    where handle = 4 :: Int


testSubackOneTopic :: Assertion
testSubackOneTopic = serviceRequest (7::Int) request [] @?=
                     ClientMessages ([(7, pack [0x90, 0x03, 0x00, 0x33, 0])],
                                     [("first", 7)])
                     where request = pack $ [0x8c, 10, -- fixed header
                                             0, 0x33, -- message ID
                                             0, 5, char 'f', char 'i', char 'r', char 's', char 't',
                                             0x01 -- qos
                                             ]


testGetSuback :: Assertion
testGetSuback = do
   serviceRequest (9::Int) (pack [0x8c, 6, 0, 7, 0, 1, char 'f', 2]) [] @?=
                     ClientMessages ([(9, pack $ [0x90, 3, 0, 7, 0])], [("f", 9)])
   serviceRequest (11::Int) (pack [0x8c, 6, 0, 8, 0, 1, char 'g', 2]) [] @?=
                     ClientMessages ([(11, pack $ [0x90, 3, 0, 8, 0])], [("g", 11)])
   serviceRequest (6::Int) (pack [0x8c, 11, 0, 13, 0, 1, char 'h', 1, 0, 2, char 'a', char 'b', 2]) [] @?=
                  ClientMessages ([(6, pack $ [0x90, 4, 0, 13, 0, 0])], [("h", 6), ("ab", 6)])


testSubscribe :: Assertion
testSubscribe = do
  serviceRequest (9::Int) (pack [0x8c, 6, 0, 7, 0, 1, char 'f', 2]) [("thingie", 1)] @?=
                   ClientMessages ([(9, pack $ [0x90, 3, 0, 7, 0])], [("thingie", 1), ("f", 9)])
  serviceRequest (9::Int) (pack [0x8c, 6, 0, 7, 0, 1, char 'f', 2]) [("foo", 1), ("bar", 2)] @?=
                   ClientMessages ([(9, pack $ [0x90, 3, 0, 7, 0])], [("foo", 1), ("bar", 2), ("f", 9)])
  serviceRequest (9::Int) (pack [0x8c, 8, 0, 7, 0, 3, char 'f', char 'o', char 'o', 2]) [] @?=
                   ClientMessages ([(9, pack $ [0x90, 3, 0, 7, 0])], [("foo", 9)])

testUnsubscribeClient :: Assertion
testUnsubscribeClient = do
  let handle = 11
  let subs = [("thingie", 11 :: Int), ("foo", 11), ("bar", 3)]
  unsubscribe 7 subs @?= subs -- no 7 in subs, should stay the same
  unsubscribe handle subs @?= [("bar", 3)] -- remove subscription


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
testNoMsgWithNoSubs = serviceRequest (7::Int) publishMsg [] @?= ClientMessages ([], [])

testOneMsgWithExactSub :: Assertion
testOneMsgWithExactSub = serviceRequest (4::Int) publishMsg [("foo", 4)] @?=
                         ClientMessages([(4, publishMsg)], [("foo", 4)])

testOneMsgWithWrongSub :: Assertion
testOneMsgWithWrongSub = serviceRequest (3::Int) publishMsg [("bar", 2)] @?= ClientMessages([], [("bar", 2)])

testOneMsgWithTwoSubs :: Assertion
testOneMsgWithTwoSubs = do
  serviceRequest (1 :: Int) publishMsg [("foo", 1), ("bar", 2)] @?=
                 ClientMessages([(1, publishMsg)], [("foo", 1), ("bar", 2)])
  serviceRequest (2 :: Int) publishMsg [("baz", 3), ("boo", 3)] @?=
                 ClientMessages([], [("baz", 3), ("boo", 3)])


testAnotherMsgWithExactSub :: Assertion
testAnotherMsgWithExactSub = do
  serviceRequest (5 :: Int) myPublish [("/foo/bar", 5)] @?= ClientMessages([(5, myPublish)], [("/foo/bar", 5)])
                where myPublish = pack $ [0x30, 16, 0, 8] ++
                                  strToBytes "/foo/bar" ++
                                  strToBytes "ohnoes"

testTwoClients :: Assertion
testTwoClients = do
  serviceRequest (5 :: Int) myPublish subscriptions @?= ClientMessages([(5, myPublish)], subscriptions)
                 where subscriptions = [("/foo/bar", 5), ("/bar/foo", 3)]
                       myPublish = pack $ [0x30, 16, 0, 8] ++
                                   strToBytes "/foo/bar" ++
                                   strToBytes "ohnoes"

pingMsg :: BS.ByteString
pingMsg = pack [0xc0, 0]

pongMsg :: BS.ByteString
pongMsg = pack [0xd0, 0]

testPing = testGroup "Ping" [ testCase "Ping" testPingImpl]

testPingImpl :: Assertion
testPingImpl = do
  serviceRequest (3 :: Int) pingMsg subscriptions @?= ClientMessages([(3, pongMsg)], subscriptions)
                where subscriptions = [("/path/to", 3)]

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
