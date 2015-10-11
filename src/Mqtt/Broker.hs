module Mqtt.Broker (
                     getMessageType
                   , Reply
                   , Subscription
                   , Subscriptions
                   , getNumTopics
                   , topicMatches
                   , serviceRequest
                   , unsubscribe
                   , Response(CloseConnection, ClientMessages)
                   ) where

import Mqtt.Message ( getMessageType
                    , getSubscriptionMsgId
                    , getNumTopics
                    , remainingLengthGetter
                    , MqttType(Connect, Subscribe, Publish, PingReq, Disconnect)
                    )
import qualified Data.ByteString.Lazy as BS
import Data.ByteString.Lazy (pack)
import Data.Binary.Get (runGet, getWord16be, getWord8, Get)
import Data.Bits (shiftR, (.&.))
import Data.Word (Word8, Word16)
import Data.Char (chr)
import Data.List.Split (splitOn)

type Topic = String
type Subscription a = (Topic, a)
type Subscriptions a = [Subscription a]
type Reply a = (a, BS.ByteString) -- a is a handle type (socket handle in prod, Int in UTs)


-- a RequestResult is the list of (handle, bytes) replies to send to clients
-- and the state (a list of subscriptions)
-- The reason why all of this is polymorphic is to enable easy testing instead
-- of using real System.IO.Handle in the tests, we can use Ints instead
type RequestResult a = ([Reply a], Subscriptions a)
data Response a = CloseConnection | ClientMessages (RequestResult a)
                  deriving (Show, Eq)



serviceRequest :: a -> BS.ByteString -> Subscriptions a -> Response a
serviceRequest handle msg subs = case getMessageType msg of
                           Connect -> simpleReply [32, 2, 0, 0]
                           Subscribe -> getSubackReply handle msg subs
                           Publish -> handlePublish msg subs
                           PingReq -> simpleReply [0xd0, 0]
                           Disconnect -> CloseConnection
                           _ -> ClientMessages ([], [])
    where simpleReply reply = ClientMessages ([(handle, pack reply)], subs)

getSubackReply :: a -> BS.ByteString -> Subscriptions a -> Response a
getSubackReply handle msg subs =
    ClientMessages ([(handle, pack $ [fixedHeader, remainingLength] ++ msgId ++ qoss)],
                    subs ++ (map (\t -> (t, handle)) topics))
    where topics = getSubscriptionTopics msg
          fixedHeader = 0x90
          msgId = serialise $ fromIntegral (getSubscriptionMsgId msg)
          qoss = take (getNumTopics msg) (repeat 0)
          remainingLength = fromIntegral $ (length qoss) + (length msgId)



serialise :: Word16 -> [Word8]
serialise x = map fromIntegral [ x `shiftR` 8, x .&. 0x00ff]


handlePublish :: BS.ByteString -> Subscriptions a -> Response a
handlePublish pkt subs = let topic = getPublishTopic pkt
                             matchingSubs = filter (\s -> topicMatches topic (fst s)) subs
                             handles = map snd matchingSubs in
                         ClientMessages (map (\h -> (h, pkt)) handles, subs)


getPublishTopic :: BS.ByteString -> String
getPublishTopic = runGet publishTopicGetter

publishTopicGetter :: Get String
publishTopicGetter = remainingLengthGetter >> getWord16be >>= getString

-- Get Monad for an MQTT string (ushort len, byte[] payload)
getString :: (Integral n) => n -> Get String
getString 0 = return ""
getString n = do
  x <- getWord8
  fmap (\xs -> [(chr. fromIntegral) x] ++ xs) (getString (n - 1))


getSubscriptionTopics :: BS.ByteString -> [String]
getSubscriptionTopics = runGet subscriptionTopicsGetter

subscriptionTopicsGetter :: Get [String]
subscriptionTopicsGetter = do
  len <- remainingLengthGetter
  _ <- getWord16be -- msgId
  let len' = len - 2 -- subtract msgId length
  subscriptionTopicsGetterInner len'

subscriptionTopicsGetterInner :: Int -> Get [String]
subscriptionTopicsGetterInner 0 = return []
subscriptionTopicsGetterInner numBytes = do
  topicLen <- getWord16be
  str <- getString topicLen
  _ <- getWord8 -- qos
  let numBytes' = (numBytes - fromIntegral topicLen - 3) -- -2 because of str len & qos
  strs <- subscriptionTopicsGetterInner numBytes'
  return $ [str] ++ strs


topicMatches :: String -> String -> Bool
topicMatches pub sub
    | pub == sub = True
    | otherwise = allPartsMatch pubElts subElts
    where pubElts = splitOn "/" pub
          subElts = splitOn "/" sub


allPartsMatch :: [String] -> [String] -> Bool
allPartsMatch pubElts subElts = let results = zipWith partMatches pubElts subElts
                                in
                                if (length subElts) > 0 && last subElts == "#"
                                then allPartsMatch (take (length pubElts - 1) pubElts) (take (length pubElts - 1) subElts)
                                else length pubElts == length subElts && all (==True) results

-- whether a part of a topic matches, including the + wildcard
partMatches :: String -> String -> Bool
partMatches pubElt subElt = pubElt == subElt || subElt == "+"

unsubscribe :: Eq a => a -> Subscriptions a -> Subscriptions a
unsubscribe handle subs = filter (\(_, h) -> h /= handle) subs
