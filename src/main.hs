module Main where

import Network
import Control.Concurrent
import System.IO (Handle, hSetBinaryMode)
import qualified Data.ByteString as BS
import Data.ByteString (hPutStr, hGetSome, append, empty, unpack)
import Control.Concurrent.STM
-- import Control.Concurrent.MVar.Strict
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
  putStrLn $ "Got a packet"
  let (request, rest) = nextMessage pkt
  putStrLn $ "Got the request and the rest. Request is " ++ show (unpack request)
  modifyMVar_ subsVar $ \subs -> do
    putStrLn $ "In the modify"
    let (subs', replies) = handleRequest handle request subs
    handleReplies replies
    return subs'
  -- mysubs <- takeMVar subsVar
  -- let (subs', replies) = handleRequest handle request mysubs
  -- handleReplies replies
  -- putMVar subsVar subs'
  -- putStrLn $ "After the modify"

  -- atomically $ do
  --   subs <- readTVar subsVar
  --   let (subs', replies) = handleRequest handle request subs
  --   -- handleReplies replies
  --   writeTVar subsVar subs'

  -- repr <- takeMVar subsVar
  --putStrLn $ "New subscriptions: " ++ show repr
  if BS.null rest
  then return rest
  else handlePacket handle rest subsVar


handleReplies :: [Reply Handle] -> IO ()
handleReplies [] = return ()
handleReplies replies = do
  putStrLn $ "Handling replies " ++ show (map (\r -> (fst r, unpack $ snd r)) replies)
  hPutStr replyHandle replyPacket
    where reply = head replies
          replyHandle = fst reply
          replyPacket = snd reply
