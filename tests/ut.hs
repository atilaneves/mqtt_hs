module Main where

import Test.Framework (defaultMain)
import Mqtt.Message.Test (testEncoding)
import Mqtt.Broker.Test (testConnack, testSuback, testPublish, testPing,
                         testWildcards, testDisconnect, testTree)
import Mqtt.Stream.Test (testStream)

tests = [ testEncoding, testConnack, testSuback, testPublish, testPing, testWildcards, testStream,
          testDisconnect, testTree
        ]

main :: IO ()
main = defaultMain tests
