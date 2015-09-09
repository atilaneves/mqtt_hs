module Mqtt.Stream.Test (testStream) where

import Test.Framework (testGroup)
import Test.Framework.Providers.HUnit
import Test.HUnit
import qualified Data.ByteString.Lazy as BS
import Data.ByteString.Lazy (pack, unpack, append, empty)
import Data.Word (Word8)
import Data.Char (ord)
import Data.Monoid (mconcat)
import Control.Monad.State.Lazy
import Mqtt.Stream (nextMessage, mqttMessages, mqttStream)


testStream = testGroup "TCP Streams"
             [ testCase "Test 0 bytes" testNoBytes
             , testCase "Test 1 byte" testOneByte
             , testCase "Test only connect header" testOnlyConnectHeader
             , testCase "Test only connect message" testOnlyConnectMsg
             , testCase "Test subscribe msg + garbage" testSubscribeMsgThenGarbage
             , testCase "Test disconnect msg" testDisconnectMsg
             , testCase "Test multiple disconnects" testMultipleDisconnect
             , testCase "Test multiple subscribes + garbage" testMultipleSubscribeThenGarbage
             , testCase "Test connack" testConnack
             , testCase "Test empty MQTT stream" testEmptyMqttStream
             , testCase "Test MQTT stream with 3 disconnects" testManyDisconnects
             , testCase "Test MQTT stream with one byte at a time" testBytesStream
             ]



-- Helper to transform a character into a byte
char :: Char -> Word8
char x = (fromIntegral $ ord x) :: Word8


subscribeMsg :: BS.ByteString
subscribeMsg = pack $ [0x8c, 0x10, -- fixed header
                       0x00, 0x21, -- message ID
                       0x00, 0x05, char 'f', char 'i', char 'r', char 's', char 't',
                       0x01, -- qos
                       0x00, 0x03, char 'f', char 'o', char 'o',
                       0x02 -- qos
                      ]

disconnectMsg :: BS.ByteString
disconnectMsg = pack [0xe0, 0]


testNoBytes :: Assertion
testNoBytes = nextMessage empty @?= (empty, empty)


testOneByte :: Assertion
testOneByte = nextMessage oneByteStr @?= (empty, oneByteStr)
    where oneByteStr = pack [0x8c]


testOnlyConnectHeader :: Assertion
testOnlyConnectHeader = nextMessage connectHdr @?= (empty, connectHdr)
    where connectHdr = pack [0x8c, 10]


testOnlyConnectMsg :: Assertion
testOnlyConnectMsg = nextMessage subscribeMsg @?= (subscribeMsg, empty)


testSubscribeMsgThenGarbage :: Assertion
testSubscribeMsgThenGarbage = nextMessage (subscribeMsg `append` garbage) @?= (subscribeMsg, garbage)
    where garbage = pack [1, 2, 3]


testConnack :: Assertion
testConnack = do
  nextMessage (pack [32, 2]) @?= (empty, pack [32, 2])
  nextMessage (pack [32, 2, 0]) @?= (empty, pack [32, 2, 0])
  nextMessage (pack  [32, 2, 0, 0]) @?= (pack [32, 2, 0, 0], empty)

testDisconnectMsg :: Assertion
testDisconnectMsg = nextMessage disconnectMsg @?= (disconnectMsg, empty)


-- repeat a bytestring N times
copies :: Int -> BS.ByteString -> BS.ByteString
copies number bytes = mconcat (replicate number bytes)

testMultipleDisconnect :: Assertion
testMultipleDisconnect = mqttMessages (copies 4 disconnectMsg) @?= (replicate 4 disconnectMsg, empty)

testMultipleSubscribeThenGarbage :: Assertion
testMultipleSubscribeThenGarbage = mqttMessages bytes @?= (replicate 5 subscribeMsg, garbage)
    where bytes = (copies 5 subscribeMsg) `append` garbage
          garbage = pack [1, 255, 3]


msgsReader :: a -> Control.Monad.State.Lazy.State [BS.ByteString] BS.ByteString
msgsReader _ = do
  msgs <- get
  if null msgs
  then return empty
  else do
    let (x:xs) = msgs
    put xs
    return x

testEmptyMqttStream :: Assertion
testEmptyMqttStream = result @?= msgs
              where result = evalState (mqttStream handle msgsReader) msgs
                    handle = 4 :: Int
                    msgs = []


testManyDisconnects :: Assertion
testManyDisconnects = result @?= msgs
              where result = evalState (mqttStream handle msgsReader) msgs
                    handle = 4 :: Int
                    msgs = map pack $ replicate 3 [0xe0, 0]


bytesReader :: Int -> Control.Monad.State.Lazy.State BS.ByteString BS.ByteString
bytesReader _ = do
  bytes <- get
  if BS.null bytes
  then return empty
  else do
    let (x:xs) = unpack bytes
    put $ pack xs
    return $ pack [x]


shouldEqual :: [BS.ByteString] -> [BS.ByteString] -> Assertion
shouldEqual x y = (map unpack x) @?= (map unpack y)

testBytesStream :: Assertion
testBytesStream = result `shouldEqual` msgs
    where result = evalState (mqttStream handle bytesReader) bytes
          handle = 3 :: Int
          msgs = map pack [[0xc0, 0], [0xc0, 0], [32, 2, 0, 0], [0xe0, 0]]
          bytes = pack [0xc0, 0, 0xc0, 0, 32, 2, 0, 0, 0xe0, 0]
