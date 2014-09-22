module Main where

import Network
import Control.Concurrent
import System.IO (Handle)
import Data.ByteString.Lazy (hPutStr, hGetContents)
import Mqtt.Broker (getReplies)

main :: IO ()
main = withSocketsDo $ do
       socket <- listenOn $ PortNumber 1883
       socketHandler socket
       return ()

socketHandler :: Socket -> IO ThreadId
socketHandler socket = do
    (handle, _, _) <- accept socket
    forkIO $ handleConnection handle
    socketHandler socket

handleConnection:: Handle -> IO ()
handleConnection handle = do
    request <- hGetContents handle
    let replies = getReplies handle request []
    --hPutStr handle (pack [32, 2, 0, 0]) -- CONNACK
    hPutStr handle (snd (head replies))
    handleConnection handle
