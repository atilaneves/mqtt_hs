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
import Data.Char (ord, chr)


type Topic = String
type Subscription = Topic
type Subscriptions = [Subscription]
type Reply a = (a, BS.ByteString) -- a is a handle type (socket handle in real life)
type RequestResult a = (Subscriptions, [Reply a])


handleRequest :: a -> BS.ByteString -> Subscriptions -> RequestResult a
handleRequest _ (uncons -> Nothing) subs = (subs, [])  -- 1st _ is xs, 2nd subscriptions
handleRequest handle packet subs = case getMessageType packet of
    Connect -> (subs, [(handle, pack [32, 2, 0, 0])]) -- connect gets connack
    Subscribe -> getSubackReply handle packet subs
    Publish -> handlePublish handle packet subs
    _ -> ([], [])


getSubackReply :: a -> BS.ByteString -> Subscriptions -> RequestResult a
getSubackReply handle pkt subs = (subs ++ [topic],
                                  [(handle, pack $ [fixedHeader, remainingLength] ++ msgId ++ qoss)])
    where topic = getSubscriptionTopic pkt
          fixedHeader = 0x90
          msgId = serialise $ fromIntegral (getSubscriptionMsgId pkt)
          qoss = take (getNumTopics pkt) (repeat 0)
          remainingLength = fromIntegral $ (length qoss) + (length msgId)


serialise :: Word16 -> [Word8]
serialise x = map fromIntegral [ x `shiftR` 8, x .&. 0x00ff]


handlePublish :: a -> BS.ByteString -> Subscriptions -> RequestResult a
handlePublish handle pkt subs = let topic = getPublishTopic pkt in
                                if topic `elem` subs
                                then (subs, [(handle, pack $ [0x30, 5, 0, 3] ++ map (fromIntegral . ord) topic)])
                                else (subs, [])


getPublishTopic :: BS.ByteString -> String
getPublishTopic pkt = stringFromEither $ runGet publishTopicGetter pkt


publishTopicGetter :: Get String
publishTopicGetter = do
  remainingLengthGetter
  topicLen <- getWord16be
  fmap (map (chr . fromIntegral) . unpack) (getByteString $ fromIntegral topicLen)


stringFromEither :: (Either String String, b) -> String
stringFromEither (Left _, _) = ""
stringFromEither (Right x, _) = x


getSubscriptionTopic :: BS.ByteString -> String
getSubscriptionTopic pkt = stringFromEither $ runGet subscriptionTopicGetter pkt

subscriptionTopicGetter :: Get String
subscriptionTopicGetter = do
  remainingLengthGetter
  getWord16be -- msgId
  topicLen <- getWord16be
  fmap (map (chr . fromIntegral) . unpack) (getByteString $ fromIntegral topicLen)
