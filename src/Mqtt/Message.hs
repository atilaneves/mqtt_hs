module Mqtt.Message (getMessageType,
                     getSubscriptionMsgId,
                     getNumTopics,
                     MqttType(Connect, ConnAck, Subscribe),
                     remainingSize) where


import qualified Data.ByteString as BS
import Data.ByteString (uncons)
import Data.Bits (shiftL, shiftR)
import Data.Binary.Strict.Get


data MqttType = Reserved1
              | Connect
              | ConnAck
              | Publish
              | PubAck
              | PubRec
              | PubRel
              | PubComp
              | Subscribe
              | SubAck
              | Unsubscribe
              | UnsubAck
              | PingReq
              | PingResp
              | Disconnect
              | Reserved2
                deriving (Enum, Show, Eq)



getMessageType :: BS.ByteString -> MqttType
getMessageType (uncons -> Nothing) = Reserved1
getMessageType (uncons -> Just (msgType, _)) = toEnum $ (fromIntegral msgType) `shiftR` 4

remainingSize :: BS.ByteString -> Int
remainingSize pkt = fromEither (runGet getRemainingSize pkt)


getRemainingSize :: Get Int
getRemainingSize = do
  getWord8 -- fixedHeader
  size <- getWord8
  return $ fromIntegral size


-- massive hack that assumes remaining length is one byte long
getSubscriptionMsgId :: (Num a) => BS.ByteString -> a
getSubscriptionMsgId (uncons -> Nothing) = 0
getSubscriptionMsgId (uncons -> Just (_, uncons -> Just(_, uncons -> Just(msgIdHi, uncons -> Just (msgIdLo, _))))) = fromIntegral $ msgIdHi `shiftL` 8 + msgIdLo



getNumTopics :: BS.ByteString -> Int
getNumTopics packet = fromEither (runGet numberOfTopicsRunner packet)

fromEither:: (Either String Int, a) -> Int
fromEither (Left _, _) = 0
fromEither (Right x, _) = x

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
