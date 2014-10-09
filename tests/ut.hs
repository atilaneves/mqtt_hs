module Main where

import Test.Framework (defaultMain)
import Mqtt.Message.Test (testEncoding)
import Mqtt.Broker.Test (testConnack, testSuback)
import Mqtt.Stream.Test (testStream)

tests = [ testEncoding, testConnack, testSuback, testStream ]

main :: IO ()
main = defaultMain tests
