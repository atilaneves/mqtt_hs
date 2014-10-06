module Main where

import Network
import Control.Concurrent
import System.IO (Handle, hSetBinaryMode)
import Data.ByteString (hPutStr, hGetContents, unpack, hGetNonBlocking, hGetSome)
import Mqtt.Broker (getReplies, Reply)

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
  --request <- hGetContents handle
  --request <- hGetNonBlocking handle 1024
  request <- hGetSome handle 1024
  putStrLn $ "request: " ++ show (unpack request)
  let replies = getReplies handle request []
  putStrLn "Going to call handleReplies"
  handleReplies replies
  putStrLn "Recursing handleConnection"
  handleConnection handle

handleReplies :: [Reply Handle] -> IO ()
handleReplies [] = putStrLn "WTF?"
handleReplies replies = do
  putStrLn "Sending reply back"
  putStrLn $ "Number of bytes: " ++ (show (length (unpack packet)))
  hPutStr handle packet
    where reply = head replies
          handle = fst reply
          packet = snd reply
