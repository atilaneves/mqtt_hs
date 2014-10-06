module Mqtt.Stream.Test (testStream) where

import Test.Framework (testGroup)
import Test.Framework.Providers.HUnit
import Test.HUnit
import Data.ByteString (pack)
import Mqtt.Stream (nextMessage)

testStream = testGroup "TCP Streams" [ testCase "Test 0 bytes" testNoStream ]


testNoStream :: Assertion
testNoStream = nextMessage emptyByteStr @?= (emptyByteStr, emptyByteStr)
               where emptyByteStr = pack []
