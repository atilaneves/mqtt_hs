module Mqtt.Stream (nextMessage, containsFullMessage, mqttMessages) where

import           Data.ByteString (pack, unpack)
import qualified Data.ByteString as BS
import           Mqtt.Message (getRemainingLength)


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


mqttMessages :: BS.ByteString -> ([BS.ByteString], BS.ByteString)
mqttMessages bytes = if containsFullMessage bytes
                     then (messages, rest)
                     else ([], bytes)
                          where (message, bytes') = nextMessage bytes
                                messages = message : moreMessages
                                (moreMessages, rest) = mqttMessages bytes'


getMqttMessages :: (Monad m) => a -> BS.ByteString -> (a -> BS.ByteString -> m BS.ByteString) -> m [BS.ByteString]
getMqttMessages handle bytes func = do
  let (msgs, bytes') = mqttMessages bytes
  if null msgs
  then do
    bytes'' <- func handle bytes'
    getMqttMessages handle bytes'' func
  else do
    msgs' <- getMqttMessages handle bytes' func
    return $ msgs ++ msgs'
