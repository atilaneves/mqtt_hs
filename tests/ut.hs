module Main where

import Test.Framework (defaultMain)
import Mqtt.Message.Test (testEncoding)
import Mqtt.Broker.Test (testConnack, testSuback)

tests = [ testEncoding, testConnack, testSuback ]

main :: IO ()
main = defaultMain tests
