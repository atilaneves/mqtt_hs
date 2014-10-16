module Main where

import Network
import Control.Concurrent
import System.IO (Handle, hSetBinaryMode)
import qualified Data.ByteString as BS
import Data.ByteString (hPutStr, hGetSome, append, empty)
import Mqtt.Broker (handleRequest, Reply, Subscription)
import Mqtt.Stream (nextMessage)


main :: IO ()
main = withSocketsDo $ do
       socket <- listenOn $ PortNumber 1883
       socketHandler socket
       return ()


socketHandler :: Socket -> IO ThreadId
socketHandler socket = do
    (handle, _, _) <- accept socket
    hSetBinaryMode handle True
    let rest = empty
    forkIO $ handleConnection handle rest
    socketHandler socket


handleConnection :: Handle -> BS.ByteString -> IO ()
handleConnection handle rest = do
  pkt <- readBytes handle rest
  rest' <- handlePacket handle pkt []
  handleConnection handle rest'

readBytes :: Handle -> BS.ByteString -> IO BS.ByteString
readBytes handle oldBytes = do
  newBytes <- hGetSome handle 1024
  return $ oldBytes `append` newBytes

handlePacket :: Handle -> BS.ByteString -> [Subscription] -> IO BS.ByteString
handlePacket handle pkt subs = do
  let (request, rest) = nextMessage pkt
  let (subs', replies) = handleRequest handle request subs
  handleReplies replies
  if BS.null rest
      then return rest
      else handlePacket handle rest subs'


handleReplies :: [Reply Handle] -> IO ()
handleReplies [] = return ()
handleReplies replies = do
  hPutStr handle packet
    where reply = head replies
          handle = fst reply
          packet = snd reply
