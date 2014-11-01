module Main where

import Test.Framework (defaultMain)
import Mqtt.Message.Test (testEncoding)
import Mqtt.Broker.Test (testConnack, testSuback, testPublish, testPing)
import Mqtt.Stream.Test (testStream)

tests = [ testEncoding, testConnack, testSuback, testPublish, testPing, testStream ]

main :: IO ()
main = defaultMain tests
