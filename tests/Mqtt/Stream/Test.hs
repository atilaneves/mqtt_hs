module Mqtt.Stream.Test (testStream) where

import Test.Framework (testGroup)
import Test.Framework.Providers.HUnit
import Test.HUnit
import qualified Data.ByteString as BS
import Data.ByteString (pack, append)
import Data.Word (Word8)
import Data.Char (ord)
import Mqtt.Stream (nextMessage)


testStream = testGroup "TCP Streams" [ testCase "Test 0 bytes" testNoBytes
                                     , testCase "Test 1 byte" testOneByte
                                     , testCase "Test only connect header" testOnlyConnectHeader
                                     , testCase "Test only connect message" testOnlyConnectMsg
                                     , testCase "Test connect msg + garbage" testConnectMsgThenGarbage
                                     ]


emptyByteStr :: BS.ByteString
emptyByteStr = pack []

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


testNoBytes :: Assertion
testNoBytes = nextMessage emptyByteStr @?= (emptyByteStr, emptyByteStr)


testOneByte :: Assertion
testOneByte = nextMessage oneByteStr @?= (emptyByteStr, oneByteStr)
    where oneByteStr = pack [0x8c]


testOnlyConnectHeader :: Assertion
testOnlyConnectHeader = nextMessage connectHdr @?= (emptyByteStr, connectHdr)
    where connectHdr = pack [0x8c, 10]


testOnlyConnectMsg :: Assertion
testOnlyConnectMsg = nextMessage subscribeMsg @?= (subscribeMsg, emptyByteStr)


testConnectMsgThenGarbage :: Assertion
testConnectMsgThenGarbage = nextMessage (subscribeMsg `append` garbage) @?= (subscribeMsg, garbage)
    where garbage = pack [1, 2, 3]
