module Mqtt.Stream (nextMessage, containsFullMessage,
                    mqttMessages, mqttStream) where

import           Data.ByteString.Lazy (pack, unpack, empty, append, uncons)
import qualified Data.ByteString.Lazy as BS
import           Mqtt.Message (getRemainingLength)


-- Takes a packet and returns the next MQTT message and the remaining bytes
nextMessage :: BS.ByteString -> (BS.ByteString, BS.ByteString)
nextMessage pkt = if containsFullMessage pkt
                  then (pack $ take size (unpack pkt), pack $ drop size (unpack pkt))
                  else (empty, pkt)
                      where size = getRemainingLength pkt + 2 -- 2 for header length


-- This returns true if there is at least one full message in the byte stream
containsFullMessage :: BS.ByteString -> Bool
containsFullMessage pkt = let remaining = getRemainingLength pkt
                              headerLen = 2
                              totalLen = remaining + headerLen in
                          remaining >= 0 && lengthAtLeast pkt totalLen

lengthAtLeast :: Integral n => BS.ByteString -> n -> Bool
lengthAtLeast pkt totalLen = BS.length pkt >= fromIntegral totalLen

-- Takes a bytestring and returns a list of MQTT messages plus a bytestring
-- of remaining bytes
mqttMessages :: BS.ByteString -> ([BS.ByteString], BS.ByteString)
mqttMessages bytes = if containsFullMessage bytes
                     then (messages, rest)
                     else ([], bytes)
                          where (message, bytes') = nextMessage bytes
                                messages = message : moreMessages
                                (moreMessages, rest) = mqttMessages bytes'


-- Produces a list of MQTT messages given a monadic function to retrieve new bytes
-- In production the Monad is IO and the function reads from a socket handle
-- In tests any monadic function can be passed in to simulate IO
mqttStream :: (Monad m) => a -> (a -> m BS.ByteString) -> m [BS.ByteString]
mqttStream = mqttStreamImpl empty


mqttStreamImpl :: (Monad m) => BS.ByteString -> a -> (a -> m BS.ByteString) -> m [BS.ByteString]
mqttStreamImpl bytes handle func = do
  let (msgs, bytes') = mqttMessages bytes
  if null msgs
  then do -- no msgs, get more bytes from source
    bytes'' <- func handle
    if BS.null bytes''
    then return []
    else mqttStreamImpl (bytes' `append` bytes'') handle func
  else do
    msgs' <- mqttStreamImpl bytes' handle func
    return $ msgs ++ msgs'
