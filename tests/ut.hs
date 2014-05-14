module Main where

import Test.Framework (defaultMain)
import Mqtt.Message.Test (test_encoding)

tests = [ test_encoding ]

main :: IO ()
main = defaultMain tests
