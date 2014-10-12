module Mqtt.Broker (getReplies, getMessageType, Reply, getNumTopics) where

import Mqtt.Message (getMessageType, getSubscriptionMsgId, getNumTopics, MqttType(Connect, Subscribe))
import qualified Data.ByteString as BS
import Data.ByteString (uncons, pack)
import Data.Bits (shiftR, (.&.))
import Data.Word (Word8, Word16)


type Topic = String
type Subscription = Topic
type Reply a = (a, BS.ByteString) -- a is a handle type (socket handle in real life)


getReplies :: a -> BS.ByteString -> [Subscription] -> [Reply a]
getReplies _ (uncons -> Nothing) _ = []  -- 1st _ is xs, 2nd subscriptions
getReplies handle packet _ = case getMessageType packet of
    Connect -> [(handle, pack [32, 2, 0, 0])] -- connect gets connack
    Subscribe -> getSubackReply handle packet
    _ -> []


getSubackReply :: a -> BS.ByteString -> [Reply a]
getSubackReply handle packet = [(handle, pack $ [fixedHeader, remainingLength] ++ msgId ++ qoss)]
    where fixedHeader = 0x90
          msgId = serialise $ fromIntegral (getSubscriptionMsgId packet)
          qoss = take (getNumTopics packet) (repeat 0)
          remainingLength = fromIntegral $ (length qoss) + (length msgId)


serialise :: Word16 -> [Word8]
serialise x = map fromIntegral [ x `shiftR` 8, x .&. 0x00ff]
