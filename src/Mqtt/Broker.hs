module Mqtt.Broker (getReplies, Reply) where

import Data.ByteString.Lazy (uncons, pack, unpack)
import qualified Data.ByteString.Lazy as BS

type Topic = String
type Subscription = Topic
type Reply a = (a, BS.ByteString) -- a is a handle type

getReplies :: a -> BS.ByteString -> [Subscription] -> [Reply a]
getReplies _ (uncons -> Nothing) _ = []
getReplies handle (uncons -> Just (connect, xs)) subscriptions = [(handle, pack [32, 2, 0, 0])]
                                                                 where connect = 1
