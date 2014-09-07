module Mqtt.Broker (getReplies, getMessageType, Reply) where

import Data.ByteString.Lazy (uncons, pack)
import Data.Bits (shiftR)
import qualified Data.ByteString.Lazy as BS

type Topic = String
type Subscription = Topic
type Reply a = (a, BS.ByteString) -- a is a handle type

getReplies :: a -> BS.ByteString -> [Subscription] -> [Reply a]
getReplies _ (uncons -> Nothing) _ = []
getReplies handle packet _ -- 1st _ is xs, 2nd subscriptions
    | getMessageType packet == 1 = [(handle, pack [32, 2, 0, 0])]
    | otherwise = []


getMessageType :: BS.ByteString -> Int
getMessageType (uncons -> Nothing) = 0
getMessageType (uncons -> Just (connect, _)) = fromIntegral $ connect `shiftR` 4
