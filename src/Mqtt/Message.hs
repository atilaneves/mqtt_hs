module Mqtt.Message (getMessageType,
                     getSubscriptionMsgId,
                     getNumTopics,
                     MqttType(Connect, ConnAck, Subscribe, Publish, PingReq, Disconnect),
                     remainingLengthGetter,
                     getRemainingLength) where


import qualified Data.ByteString.Lazy as BS
import Data.ByteString.Lazy (uncons)
import Data.Bits (shiftL, shiftR, (.&.))
import Data.Binary.Get
import Data.Word (Word16)


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


getRemainingLength :: BS.ByteString -> Int
getRemainingLength pkt = if (BS.length pkt) < 2 then -1
                         else runGet remainingLengthGetter pkt

remainingLengthGetter :: Get Int
remainingLengthGetter = do
  _ <- getWord8 -- fixedHeader
  let value = 0
  let multiplier = 1
  remainingLengthGetterInner value multiplier

remainingLengthGetterInner :: Int -> Int -> Get Int
remainingLengthGetterInner value multiplier = do
  digit <- getWord8
  let newValue = value + (fromIntegral digit .&. 127) * multiplier
  if digit .&. 128 == 0
  then return newValue
  else remainingLengthGetterInner newValue (multiplier * 128)


getSubscriptionMsgId :: BS.ByteString -> Word16
getSubscriptionMsgId pkt = runGet subscriptionIdGetter pkt

subscriptionIdGetter :: Get Word16
subscriptionIdGetter = do
  _ <- remainingLengthGetter
  msgIdHi <- getWord8
  msgIdLo <- getWord8
  return $ (fromIntegral msgIdHi) `shiftL` 8 + (fromIntegral msgIdLo)


getNumTopics :: BS.ByteString -> Int
getNumTopics packet = runGet numberOfTopicsRunner packet


numberOfTopicsRunner :: Get Int
numberOfTopicsRunner = do
  _ <- getWord8 -- fixedHeader
  _ <- getWord8 -- remaining length
  _ <- getWord16be -- msgId
  numberOfTopics


numberOfTopics :: Get Int
numberOfTopics = do
  empty <- isEmpty
  if empty
     then return 0
     else do
       strLen <- getWord16be
       _ <- getByteString $ fromIntegral strLen -- topic string
       _ <- getWord8 -- qos
       fmap (+1) numberOfTopics
