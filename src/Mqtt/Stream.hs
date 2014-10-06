module Mqtt.Stream (nextMessage) where

import qualified Data.ByteString as BS
import Data.ByteString (pack)

nextMessage :: BS.ByteString -> (BS.ByteString, BS.ByteString)
nextMessage _ = (pack [], pack [])
