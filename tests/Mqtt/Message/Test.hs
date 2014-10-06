module Mqtt.Message.Test (testEncoding) where

import Test.Framework (testGroup)
import Test.Framework.Providers.HUnit
import Test.HUnit
import Data.ByteString (pack)
import Data.Word (Word8)
import Data.Char (ord)
import Mqtt.Broker (getNumTopics)


-- Helper to transform a character into a byte
char :: Char -> Word8
char x = (fromIntegral $ ord x) :: Word8


testEncoding = testGroup "Encoding" [ testCase "Test get number of topics" testDecodeNumberTopics]


testDecodeNumberTopics :: Assertion
testDecodeNumberTopics = getNumTopics packet @?= 2
    where packet = pack $ [0x8c, 0x10, -- fixed header
                           0x00, 0x21, -- message ID
                           0x00, 0x05, char 'f', char 'i', char 'r', char 's', char 't',
                           0x01, -- qos
                           0x00, 0x03, char 'f', char 'o', char 'o',
                           0x02 -- qos
                          ]
