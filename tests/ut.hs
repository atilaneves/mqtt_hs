module Main where

import Test.Framework (defaultMain)
import Mqtt.Broker.Test (testConnack)

tests = [ testConnack ]

main :: IO ()
main = defaultMain tests
