module Mqtt.Broker (getReplies, getMessageType, Reply, getNumTopics) where

import Data.ByteString.Lazy (uncons, pack)
import Data.Bits (shiftR, shiftL, (.&.))
import Data.Word (Word8, Word16)
import Data.Binary.Get
import qualified Data.ByteString.Lazy as BS

type Topic = String
type Subscription = Topic
type Reply a = (a, BS.ByteString) -- a is a handle type (socket handle in real life)

getReplies :: a -> BS.ByteString -> [Subscription] -> [Reply a]
getReplies _ (uncons -> Nothing) _ = []  -- 1st _ is xs, 2nd subscriptions
getReplies handle packet _ = case getMessageType packet of
    1 -> [(handle, pack [32, 2, 0, 0])] -- connect gets connack
    8 -> getSubackReply handle packet
    _ -> []


getMessageType :: BS.ByteString -> Int
getMessageType (uncons -> Nothing) = 0
getMessageType (uncons -> Just (msgType, _)) = fromIntegral $ msgType `shiftR` 4

getSubackReply :: a -> BS.ByteString -> [Reply a]
getSubackReply handle packet = [(handle, pack $ [fixedHeader, remainingLength] ++ msgId ++ qoss)]
    where fixedHeader = 0x90
          msgId = serialise $ getSubscriptionMsgId packet
          qoss = take (getNumTopics packet) (repeat 0)
          remainingLength = fromIntegral $ (length qoss) + (length msgId)

-- massive hack that assumes remaining length is one byte long
getSubscriptionMsgId :: (Num a) => BS.ByteString -> a
getSubscriptionMsgId (uncons -> Nothing) = 0
getSubscriptionMsgId (uncons -> Just (_, uncons -> Just(_, uncons -> Just(msgIdHi, uncons -> Just (msgIdLo, _))))) = fromIntegral $ msgIdHi `shiftL` 8 + msgIdLo


serialise :: Word16 -> [Word8]
serialise x = map fromIntegral [ x `shiftR` 8, x .&. 0x00ff]


getNumTopics :: BS.ByteString -> Int
getNumTopics packet = runGet numberOfTopicsRunner packet

numberOfTopicsRunner :: Get Int
numberOfTopicsRunner = do
  getWord8 -- fixedHeader
  getWord8 -- remaining length
  getWord16be -- msgId
  numberOfTopics


numberOfTopics :: Get Int
numberOfTopics = do
  empty <- isEmpty
  if empty
     then return 0
     else do
       strLen <- getWord16be
       getByteString $ fromIntegral strLen -- topic string
       getWord8 -- qos
       fmap (+1) numberOfTopics
