module Mqtt.Stream (nextMessage, containsFullMessage,
                    mqttMessages, mqttStream) where

import           Data.ByteString (pack, unpack, empty, append)
import qualified Data.ByteString as BS
import           Mqtt.Message (getRemainingLength)
import Control.Monad.State.Lazy


-- Takes a packet and returns the next MQTT message and the remaining bytes
nextMessage :: BS.ByteString -> (BS.ByteString, BS.ByteString)
nextMessage pkt = if containsFullMessage pkt
                  then (pack $ take size (unpack pkt), pack $ drop size (unpack pkt))
                  else (pack [], pkt)
                      where size = getRemainingLength pkt + 2 -- 2 for header length


-- This returns true if there is at least one full message in the byte stream
containsFullMessage :: BS.ByteString -> Bool
containsFullMessage pkt = let size = getRemainingLength pkt in
                          size >= 0 && BS.length pkt >= size

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
  then do
    bytes'' <- func handle
    if BS.null bytes''
    then return []
    else mqttStreamImpl (bytes' `append` bytes'') handle func
  else do
    msgs' <- mqttStreamImpl bytes' handle func
    return $ msgs ++ msgs'
