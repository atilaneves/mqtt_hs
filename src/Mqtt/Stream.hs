module Mqtt.Stream (nextMessage) where

import Mqtt.Message (getRemainingLength)
import qualified Data.ByteString as BS
import Data.ByteString (pack, unpack)


nextMessage :: BS.ByteString -> (BS.ByteString, BS.ByteString)
nextMessage pkt = if containsFullMessage pkt
                  then (pack $ take size (unpack pkt), pack $ drop size (unpack pkt))
                  else (pack [], pkt)
                      where size = getRemainingLength pkt + 2 -- 2 for header length


-- This returns true if there is at least one full message in the byte stream
containsFullMessage :: BS.ByteString -> Bool
containsFullMessage pkt = let size = getRemainingLength pkt in
                          size >= 0 && BS.length pkt >= size
