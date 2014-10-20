module Mqtt.Broker (
                     getMessageType
                   , Reply
                   , Subscription
                   , Subscriptions
                   , getNumTopics
                   , handleRequest
                   ) where

import Mqtt.Message ( getMessageType
                    , getSubscriptionMsgId
                    , getNumTopics
                    , remainingLengthGetter
                    , MqttType(Connect, Subscribe, Publish)
                    )
import qualified Data.ByteString as BS
import Data.ByteString (uncons, pack, unpack)
import Data.Binary.Strict.Get
import Data.Bits (shiftR, (.&.))
import Data.Word (Word8, Word16)
import Data.Char (chr)


type Topic = String
type Subscription a = (Topic, a)
type Subscriptions a = [Subscription a]
type Reply a = (a, BS.ByteString) -- a is a handle type (socket handle in real life)
type RequestResult a = (Subscriptions a, [Reply a])


handleRequest :: a -> BS.ByteString -> Subscriptions a -> RequestResult a
handleRequest _ (uncons -> Nothing) subs = (subs, [])  -- 1st _ is xs, 2nd subscriptions
handleRequest handle packet subs = case getMessageType packet of
    Connect -> (subs, [(handle, pack [32, 2, 0, 0])]) -- connect gets connack
    Subscribe -> getSubackReply handle packet subs
    Publish -> handlePublish handle packet subs
    _ -> ([], [])


getSubackReply :: a -> BS.ByteString -> Subscriptions a -> RequestResult a
getSubackReply handle pkt subs = (subs ++ (map (\t -> (t, handle)) topics),
                                  [(handle, pack $ [fixedHeader, remainingLength] ++ msgId ++ qoss)])
    where topics = getSubscriptionTopics pkt
          fixedHeader = 0x90
          msgId = serialise $ fromIntegral (getSubscriptionMsgId pkt)
          qoss = take (getNumTopics pkt) (repeat 0)
          remainingLength = fromIntegral $ (length qoss) + (length msgId)


serialise :: Word16 -> [Word8]
serialise x = map fromIntegral [ x `shiftR` 8, x .&. 0x00ff]


handlePublish :: a -> BS.ByteString -> Subscriptions a -> RequestResult a
handlePublish handle pkt subs = let topic = getPublishTopic pkt in
                                if haveSubscriptionFor topic subs
                                then (subs, [(handle, pkt)])
                                else (subs, [])

haveSubscriptionFor :: String -> Subscriptions a -> Bool
haveSubscriptionFor topic subs = if topic `elem` (map fst subs)
                                 then True
                                 else False


getPublishTopic :: BS.ByteString -> String
getPublishTopic pkt = let result = fst (runGet publishTopicGetter pkt) in
                      either (\_ -> "") id result

publishTopicGetter :: Get String
publishTopicGetter = remainingLengthGetter >> getWord16be >>= getString

getString :: (Integral n) => n -> Get String
getString strLen = fmap byteStringToString (getByteString $ fromIntegral strLen)

byteStringToString :: BS.ByteString -> String
byteStringToString = map (chr . fromIntegral) . unpack

getSubscriptionTopics :: BS.ByteString -> [String]
getSubscriptionTopics pkt = let result = fst (runGet subscriptionTopicsGetter pkt) in
                            either (\_ -> [""]) id result

subscriptionTopicsGetter :: Get [String]
subscriptionTopicsGetter = do
  len <- remainingLengthGetter
  getWord16be -- msgId
  let len' = len - 2 -- subtract msgId length
  subscriptionTopicsGetterInner len'

subscriptionTopicsGetterInner :: Int -> Get [String]
subscriptionTopicsGetterInner 0 = return []
subscriptionTopicsGetterInner numBytes = do
  topicLen <- getWord16be
  str <- getString topicLen
  getWord8 -- qos
  let numBytes' = (numBytes - fromIntegral topicLen - 3) -- -2 because of str len & qos
  strs <- subscriptionTopicsGetterInner numBytes'
  return $ [str] ++ strs
