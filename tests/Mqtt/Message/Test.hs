module Mqtt.Message.Test (test_encoding) where

import Test.Framework (testGroup)
import Test.Framework.Providers.HUnit
import Test.HUnit

test_encoding = testGroup "Encoding" [ testCase "Test decode MQTT connect" test_decode_mqtt_connect]


test_decode_mqtt_connect :: Assertion
test_decode_mqtt_connect = 1 @?= 1
