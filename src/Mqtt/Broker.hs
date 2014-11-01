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
                    , MqttType(Connect, Subscribe, Publish, PingReq)
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
    Connect -> simpleReply handle subs [32, 2, 0, 0]
    Subscribe -> getSubackReply handle packet subs
    Publish -> handlePublish packet subs
    PingReq -> simpleReply handle subs [0xd0, 0]
    _ -> ([], [])

-- convenience function to simply return a fixed sequence of bytes
simpleReply :: a -> Subscriptions a -> [Word8] -> RequestResult a
simpleReply handle subs reply = (subs, [(handle, pack reply)])


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


handlePublish :: BS.ByteString -> Subscriptions a -> RequestResult a
handlePublish pkt subs = let topic = getPublishTopic pkt
                             matchingSubs = filter (\s -> subscriptionMatches topic (fst s)) subs
                             handles = map snd matchingSubs in
                         (subs, map (\h -> (h, pkt)) handles)

subscriptionMatches :: String -> String -> Bool
subscriptionMatches topic sub = topic == sub


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
