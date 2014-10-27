module Main where

import Network
import Control.Concurrent
import System.IO (Handle, hSetBinaryMode)
import qualified Data.ByteString as BS
import Data.ByteString (hPutStr, hGetSome, append, empty)
import Mqtt.Broker (handleRequest, Reply, Subscription)
import Mqtt.Stream (nextMessage)


type SubscriptionIO = Subscription Handle
type Subscriptions = MVar [Subscription Handle]

main :: IO ()
main = withSocketsDo $ do
         subs <- newMVar [] -- empty subscriptions list
         socket <- listenOn $ PortNumber 1883
         socketHandler subs socket
         return ()


socketHandler :: Subscriptions -> Socket -> IO ThreadId
socketHandler subs socket = do
    (handle, _, _) <- accept socket
    hSetBinaryMode handle True
    let rest = empty
    forkIO $ handleConnection handle rest subs
    socketHandler subs socket


handleConnection :: Handle -> BS.ByteString -> Subscriptions -> IO ()
handleConnection handle bytes subs = do
  pkt <- readBytes handle bytes
  bytes' <- handlePacket handle pkt subs
  handleConnection handle bytes' subs

readBytes :: Handle -> BS.ByteString -> IO BS.ByteString
readBytes handle bytes = do
  bytes' <- hGetSome handle 1024
  return $ bytes `append` bytes'

handlePacket :: Handle -> BS.ByteString -> Subscriptions -> IO BS.ByteString
handlePacket handle pkt subsVar = do
  let (request, rest) = nextMessage pkt

  modifyMVar_ subsVar $ \subs -> do
    let (subs', replies) = handleRequest handle request subs
    handleReplies replies
    return subs'

  if BS.null rest
  then return rest
  else handlePacket handle rest subsVar


handleReplies :: [Reply Handle] -> IO ()
handleReplies [] = return ()
handleReplies replies = do
  hPutStr replyHandle replyPacket
  handleReplies (tail replies)
    where reply = head replies
          replyHandle = fst reply
          replyPacket = snd reply
