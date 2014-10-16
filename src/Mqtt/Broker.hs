module Mqtt.Broker (getReplies
                   , getMessageType
                   , Reply
                   , getNumTopics
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
type Reply a = (a, BS.ByteString) -- a is a handle type (socket handle in real life)


getReplies :: a -> BS.ByteString -> [Subscription] -> [Reply a]
getReplies _ (uncons -> Nothing) _ = []  -- 1st _ is xs, 2nd subscriptions
getReplies handle packet subs = case getMessageType packet of
    Connect -> [(handle, pack [32, 2, 0, 0])] -- connect gets connack
    Subscribe -> getSubackReply handle packet
    Publish -> handlePublish handle packet subs
    _ -> []


getSubackReply :: a -> BS.ByteString -> [Reply a]
getSubackReply handle packet = [(handle, pack $ [fixedHeader, remainingLength] ++ msgId ++ qoss)]
    where fixedHeader = 0x90
          msgId = serialise $ fromIntegral (getSubscriptionMsgId packet)
          qoss = take (getNumTopics packet) (repeat 0)
          remainingLength = fromIntegral $ (length qoss) + (length msgId)


serialise :: Word16 -> [Word8]
serialise x = map fromIntegral [ x `shiftR` 8, x .&. 0x00ff]


handlePublish :: a -> BS.ByteString -> [Subscription] -> [Reply a]
handlePublish _ _ [] = []
handlePublish handle pkt subs = let topic = getTopic pkt in
                                if topic `elem` subs
                                then [(handle, pack $ [0x30, 5, 0, 3] ++ map (fromIntegral . ord) topic)]
                                else []


getTopic :: BS.ByteString -> String
getTopic pkt = stringFromEither $ runGet topicGetter pkt


topicGetter :: Get String
topicGetter = do
  remainingLengthGetter
  topicLen <- getWord16be
  fmap (map (chr . fromIntegral) . unpack) (getByteString $ fromIntegral topicLen)


stringFromEither :: (Either String String, b) -> String
stringFromEither (Left _, _) = ""
stringFromEither (Right x, _) = x
