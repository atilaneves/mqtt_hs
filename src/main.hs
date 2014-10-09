module Main where

import Network
import Control.Concurrent
import System.IO (Handle, hSetBinaryMode)
import qualified Data.ByteString as BS
import Data.ByteString as BS (null)
import Data.ByteString (hPutStr, hGetContents, pack, unpack, hGetNonBlocking, hGetSome)
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
  putStrLn "Getting pkt"
  pkt <- hGetSome handle 1024
  putStrLn "handling packet"
  handlePacket handle pkt
  putStrLn "recursing handle connection"
  handleConnection handle

  --request <- hGetContents handle
  --request <- hGetNonBlocking handle 1024
  --request <- hGetSome handle 1024

  -- putStrLn $ "request: " ++ show (unpack request)
  -- let replies = getReplies handle request []
  -- putStrLn "Going to call handleReplies"
  -- handleReplies replies
  -- putStrLn "Recursing handleConnection"
  -- handleConnection handle rest



handlePacket :: Handle -> BS.ByteString -> IO ()
--handlePacket pkt = let (request, rest) = nextMessage pkt in
handlePacket handle pkt = do
  let (request, rest) = nextMessage pkt
  putStrLn $ "request: " ++ show (unpack request)
  let replies = getReplies handle request []
  putStrLn "Going to call handleReplies"
  handleReplies replies
  putStrLn "Maybe recursing handlePacket"
  if BS.null rest
  then return ()
  else handlePacket handle rest


handleReplies :: [Reply Handle] -> IO ()
handleReplies [] = putStrLn "WTF?"
handleReplies replies = do
  putStrLn "Sending reply back"
  putStrLn $ "Number of bytes: " ++ (show (length (unpack packet)))
  hPutStr handle packet
    where reply = head replies
          handle = fst reply
          packet = snd reply
