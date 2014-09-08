module Main where

import Test.Framework (defaultMain)
import Mqtt.Broker.Test (testConnack, testSuback)

tests = [ testConnack, testSuback ]

main :: IO ()
main = defaultMain tests
