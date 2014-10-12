module Main where

import Network
import Control.Concurrent
import System.IO (Handle, hSetBinaryMode)
import qualified Data.ByteString as BS
import Data.ByteString (hPutStr, hGetSome)
import Mqtt.Broker (getReplies, Reply)
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
    forkIO $ handleConnection handle
    socketHandler socket


handleConnection:: Handle -> IO ()
handleConnection handle = do
  pkt <- hGetSome handle 1024
  handlePacket handle pkt
  handleConnection handle


handlePacket :: Handle -> BS.ByteString -> IO ()
handlePacket handle pkt = do
  let (request, rest) = nextMessage pkt
  let replies = getReplies handle request []
  handleReplies replies
  if BS.null rest
      then return ()
      else handlePacket handle rest


handleReplies :: [Reply Handle] -> IO ()
handleReplies [] = return ()
handleReplies replies = do
  hPutStr handle packet
    where reply = head replies
          handle = fst reply
          packet = snd reply
