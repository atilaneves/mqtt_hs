module Mqtt.Trie (SubscriptionTree(SubscriptionTree), applyForTopic) where

import Mqtt.Broker (Subscription)

data SubscriptionTree a = SubscriptionTree [Subscription a]


applyForTopic :: (Monad m) => (a -> m b) -> String -> SubscriptionTree a -> [m b]
applyForTopic _ _ _ = []
