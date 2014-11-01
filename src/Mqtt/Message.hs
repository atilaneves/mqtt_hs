module Mqtt.Message (getMessageType,
                     getSubscriptionMsgId,
                     getNumTopics,
                     MqttType(Connect, ConnAck, Subscribe, Publish, PingReq),
                     remainingLengthGetter,
                     getRemainingLength) where


import qualified Data.ByteString as BS
import Data.ByteString (uncons)
import Data.Bits (shiftL, shiftR, (.&.))
import Data.Binary.Strict.Get
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
getRemainingLength pkt = let (result, _) = runGet remainingLengthGetter pkt in
                         case result of
                           Left _ -> -1
                           Right x -> x

remainingLengthGetter :: Get Int
remainingLengthGetter = do
  getWord8 -- fixedHeader
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
getSubscriptionMsgId pkt = fromEither $ runGet subscriptionIdGetter pkt

subscriptionIdGetter :: Get Word16
subscriptionIdGetter = do
  remainingLengthGetter
  msgIdHi <- getWord8
  msgIdLo <- getWord8
  return $ (fromIntegral msgIdHi) `shiftL` 8 + (fromIntegral msgIdLo)


getNumTopics :: BS.ByteString -> Int
getNumTopics packet = fromEither (runGet numberOfTopicsRunner packet)


fromEither:: (Num n) => (Either String n, a) -> n
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
