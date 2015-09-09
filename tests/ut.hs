module Main where

import Test.Framework (defaultMain)
import Mqtt.Message.Test (testEncoding)
import Mqtt.Broker.Test (testConnack, testSuback, testPublish, testPing,
                                    testWildcards, testDisconnect, testReplyStream)
import Mqtt.Stream.Test (testStream)

tests = [ testEncoding, testConnack, testSuback, testPublish, testPing, testWildcards, testStream,
          testDisconnect, testReplyStream
        ]

main :: IO ()
main = defaultMain tests
