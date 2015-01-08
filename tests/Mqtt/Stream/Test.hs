module Mqtt.Stream.Test (testStream) where

import Test.Framework (testGroup)
import Test.Framework.Providers.HUnit
import Test.HUnit
import qualified Data.ByteString as BS
import Data.ByteString (pack, append, empty)
import Data.Word (Word8)
import Data.Char (ord)
import Data.Monoid (mconcat)
import Mqtt.Stream (nextMessage, mqttMessages)


testStream = testGroup "TCP Streams"
             [ testCase "Test 0 bytes" testNoBytes
             , testCase "Test 1 byte" testOneByte
             , testCase "Test only connect header" testOnlyConnectHeader
             , testCase "Test only connect message" testOnlyConnectMsg
             , testCase "Test subscribe msg + garbage" testSubscribeMsgThenGarbage
             , testCase "Test disconnect msg" testDisconnectMsg
             , testCase "Test multiple disconnects" testMultipleDisconnect
             , testCase "Test multiple subscribes + garbage" testMultipleSubscribeThenGarbage
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
