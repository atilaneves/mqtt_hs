module Mqtt.Broker (getReplies, getMessageType, Reply) where

import Data.ByteString.Lazy (uncons, pack)
import Data.Bits (shiftR, shiftL)
import qualified Data.ByteString.Lazy as BS

type Topic = String
type Subscription = Topic
type Reply a = (a, BS.ByteString) -- a is a handle type (socket handle in real life)

getReplies :: a -> BS.ByteString -> [Subscription] -> [Reply a]
getReplies _ (uncons -> Nothing) _ = []
getReplies handle packet _ -- 1st _ is xs, 2nd subscriptions
    | getMessageType packet == 1 = [(handle, pack [32, 2, 0, 0])] --connect gets connack
    | getMessageType packet == 8 = [(handle, pack [0x90, 0x04, 0x00, getSubscriptionMsgId packet, 0x00])] --subscribe gets suback
    | otherwise = []


getMessageType :: BS.ByteString -> Int
getMessageType (uncons -> Nothing) = 0
getMessageType (uncons -> Just (msgType, _)) = fromIntegral $ msgType `shiftR` 4


-- massive hack that assumes remaining length is one byte long
getSubscriptionMsgId :: (Num a) => BS.ByteString -> a
getSubscriptionMsgId (uncons -> Nothing) = 0
getSubscriptionMsgId (uncons -> Just (_, uncons -> Just(_, uncons -> Just(msgIdHi, uncons -> Just (msgIdLo, _))))) = fromIntegral $ msgIdHi `shiftL` 8 + msgIdLo
