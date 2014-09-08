module Mqtt.Broker (getReplies, getMessageType, Reply) where

import Data.ByteString.Lazy (uncons, pack)
import Data.Bits (shiftR)
import qualified Data.ByteString.Lazy as BS

type Topic = String
type Subscription = Topic
type Reply a = (a, BS.ByteString) -- a is a handle type (socket handle in real life)

getReplies :: a -> BS.ByteString -> [Subscription] -> [Reply a]
getReplies _ (uncons -> Nothing) _ = []
getReplies handle packet _ -- 1st _ is xs, 2nd subscriptions
    | getMessageType packet == 1 = [(handle, pack [32, 2, 0, 0])]
    | getMessageType packet == 8 = [(handle, pack [0x90, 0x03, 0x00, 0x21, 0x00])]
    | otherwise = []


getMessageType :: BS.ByteString -> Int
getMessageType (uncons -> Nothing) = 0
getMessageType (uncons -> Just (connect, _)) = fromIntegral $ connect `shiftR` 4
