module Mqtt.Message.Test (testEncoding) where

import Test.Framework (testGroup)
import Test.Framework.Providers.HUnit
import Test.HUnit
import Data.ByteString.Lazy (pack)
import Data.Word (Word8)
import Data.Char (ord)
import Mqtt.Message (getNumTopics,
                     getMessageType,
                     getRemainingLength,
                     getSubscriptionMsgId,
                     MqttType(Connect, ConnAck))
import qualified Data.ByteString.Lazy as BS


-- Helper to transform a character into a byte
char :: Char -> Word8
char x = (fromIntegral $ ord x) :: Word8


testEncoding = testGroup "Encoding" [ testCase "Test get number of topics" testDecodeNumberTopics
                                    , testCase "Test getting the message type of a packet" testGetMessageType
                                    , testCase "Test getting the remaining size" testGetRemainingSize
                                    , testCase "Test getting the subscription id" testGetSubscriptionId
                                    ]


connectMsg :: BS.ByteString
connectMsg = pack $ [0x8c, 0x10, -- fixed header
                     0x00, 0x21, -- message ID
                     0x00, 0x05, char 'f', char 'i', char 'r', char 's', char 't',
                     0x01, -- qos
                     0x00, 0x03, char 'f', char 'o', char 'o',
                     0x02 -- qos
                    ]


testDecodeNumberTopics :: Assertion
testDecodeNumberTopics = getNumTopics connectMsg @?= 2


-- Test that message types are returned correctly from a byte string
testGetMessageType :: Assertion
testGetMessageType = do
  getMessageType (pack [0x10, 0x2a]) @?= Connect
  getMessageType (pack [0x20, 0x2a]) @?= ConnAck


testGetRemainingSize :: Assertion
testGetRemainingSize = do
  getRemainingLength connectMsg @?= 16
  getRemainingLength (pack [0x15, 5]) @?= 5
  getRemainingLength (pack [0x27, 7]) @?= 7
  getRemainingLength (pack [0x12, 0xc1, 0x02]) @?= 321
  getRemainingLength (pack [0x12, 0x83, 0x02]) @?= 259
  getRemainingLength (pack [0x12, 0x85, 0x80, 0x80, 0x01]) @?= 2097157


testGetSubscriptionId :: Assertion
testGetSubscriptionId = do
  getSubscriptionMsgId (pack [0x80, 2, 0, 4]) @?= 4
  getSubscriptionMsgId (pack [0x80, 2, 1, 4]) @?= 260
