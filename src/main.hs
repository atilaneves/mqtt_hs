module Main where

import Network
import Control.Concurrent
import System.IO

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

handleConnection:: Handle -> IO()
handleConnection handle = do
    request <- hGetLine handle
    hPutStrLn handle ("MQTT reply! Nah, just kidding, but your request was:\n" ++ request)
    handleConnection handle
