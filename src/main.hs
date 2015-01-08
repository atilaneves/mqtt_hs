module Main where

import Network
import Control.Concurrent
import System.IO (Handle, hSetBinaryMode, hClose)
import qualified Data.ByteString as BS
import Data.ByteString (hPutStr, hGetSome, append, empty, pack)
import Mqtt.Broker (serviceRequest, Reply, Subscription, Response(ClientMessages))
import Mqtt.Stream (nextMessage)
import Control.Concurrent.STM;


type SubscriptionIO = Subscription Handle
type Subscriptions = TVar [Subscription Handle]

main :: IO ()
main = withSocketsDo $ do
         subs <- atomically $ newTVar [] -- empty subscriptions list
         socket <- listenOn $ PortNumber 1883
         socketHandler subs socket
         return ()


socketHandler :: Subscriptions -> Socket -> IO ThreadId
socketHandler subs socket = do
  (handle, _, _) <- accept socket
  hSetBinaryMode handle True
  forkIO $ handleConnection handle empty subs -- empty: no bytes yet
  socketHandler subs socket


handleConnection :: Handle -> BS.ByteString -> Subscriptions -> IO ()
handleConnection handle bytes subs = do
  pkt <- readBytes handle bytes
  let (msg, pkt') = nextMessage pkt
  if msg == pack [0xe0, 0]
  then hClose handle
  else do
    bytes' <- handlePacket handle msg pkt' subs
    handleConnection handle bytes' subs

readBytes :: Handle -> BS.ByteString -> IO BS.ByteString
readBytes handle bytes = do
  bytes' <- hGetSome handle 1024
  return $ bytes `append` bytes'

handlePacket :: Handle -> BS.ByteString -> BS.ByteString -> Subscriptions -> IO BS.ByteString
handlePacket handle msg rest subsVar = do

  replies <- atomically $ do
               subs <- readTVar subsVar
               let ClientMessages (replies, subs') = serviceRequest handle msg subs
               writeTVar subsVar subs'
               return replies
  handleReplies replies

  if BS.null rest
  then return rest
  else handlePacket handle msg' rest' subsVar
       where (msg', rest') = nextMessage rest


handleReplies :: [Reply Handle] -> IO ()
handleReplies [] = return ()
handleReplies replies = do
  hPutStr replyHandle replyPacket
  handleReplies (tail replies)
    where reply = head replies
          replyHandle = fst reply
          replyPacket = snd reply
