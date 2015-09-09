module Main where

import Network
import Control.Concurrent
import System.IO (Handle, hSetBinaryMode, hClose)
import qualified Data.ByteString.Lazy as BS
import qualified Data.ByteString.Lazy as BS (null, append)
import Data.ByteString.Lazy (hPutStr, hGet, append, empty, pack, unpack, hGetNonBlocking)
import Mqtt.Broker (serviceRequest, Reply, Subscription, Response(ClientMessages), Response(CloseConnection))
import Mqtt.Stream (nextMessage, mqttStream)
import Control.Concurrent.STM


type SubscriptionIO = Subscription Handle
type Subscriptions = TVar [Subscription Handle]

main :: IO ()
main = withSocketsDo $ do
         putStrLn "main"
         subs <- atomically $ newTVar [] -- empty subscriptions list
         socket <- listenOn $ PortNumber 1883
         socketHandler subs socket
         return ()


socketHandler :: Subscriptions -> Socket -> IO ThreadId
socketHandler subs socket = do
  (handle, _, _) <- accept socket
  putStrLn $ "socketHandler on " ++ (show handle)
  hSetBinaryMode handle True
  forkIO $ handleConnection handle subs
  socketHandler subs socket

handleConnection :: Handle -> Subscriptions -> IO ()
handleConnection handle subsVar = do
  handleConnectionImpl handle subsVar empty
  putStrLn $ "Closing handle " ++ (show handle)
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
      putStrLn $ "recursing cos we's got bytes: " ++ (show $ unpack bytes'')
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
    putStrLn $ "Replies: " ++ (show $ map (unpack . snd) replies)
    handleReplies replies
    if null replies
    then do
      putStrLn $ "Closing time... for " ++ (show handle)
      return ()
    else handleConnectionImpl handle subsVar bytes'


handleReplies :: [Reply Handle] -> IO ()
handleReplies [] = return ()
handleReplies (reply:replies) = do
  hPutStr replyHandle replyPacket
  handleReplies replies
    where (replyHandle, replyPacket) = reply
