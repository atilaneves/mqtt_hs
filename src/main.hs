module Main where

import Network
import Control.Concurrent
import System.IO (Handle, hSetBinaryMode, hClose, hIsClosed)
import qualified Data.ByteString.Lazy as BS
import qualified Data.ByteString.Lazy as BS (null, append)
import Data.ByteString.Lazy (hPutStr, hGet, append, empty, pack, unpack, hGetNonBlocking)
import Mqtt.Broker (unsubscribe, serviceRequest, Reply, Subscription,
                    Response(ClientMessages), Response(CloseConnection))
import Mqtt.Stream (nextMessage, mqttStream)
import Control.Concurrent.STM


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
  forkIO $ handleConnection handle subs
  socketHandler subs socket

handleConnection :: Handle -> Subscriptions -> IO ()
handleConnection handle subsVar = do
  handleConnectionImpl handle subsVar empty
  atomically $ do
    modifyTVar subsVar (\s -> unsubscribe handle s)
  hClose handle

handleConnectionImpl :: Handle -> Subscriptions -> BS.ByteString -> IO ()
handleConnectionImpl handle subsVar bytes = do
  let (msg, bytes') = nextMessage bytes
  if BS.null msg
  then do
    bytes'' <- hGetNonBlocking handle 1024
    if BS.null bytes''
    then do
      handleConnectionImpl handle subsVar bytes'
    else do
      handleConnectionImpl handle subsVar (bytes' `BS.append` bytes'')
  else do
    replies <- atomically $ do
                 subs <- readTVar subsVar
                 let response = serviceRequest handle msg subs
                 case response of
                   CloseConnection -> return []
                   ClientMessages (replies, subs') -> do
                     writeTVar subsVar subs'
                     return replies
    handleReplies replies
    closed <- hIsClosed handle
    if null replies || closed
    then do
      return ()
    else handleConnectionImpl handle subsVar bytes'


handleReplies :: [Reply Handle] -> IO ()
handleReplies [] = return ()
handleReplies (reply:replies) = do
  closed <- hIsClosed replyHandle
  if closed
  then return ()
  else do
    hPutStr replyHandle replyPacket
    handleReplies replies
    where (replyHandle, replyPacket) = reply
