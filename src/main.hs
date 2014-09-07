module Main where

import Network
import Control.Concurrent
import System.IO (hGetLine, Handle)
import Data.ByteString.Lazy (pack, hPutStr, hGetContents)

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
    request <- hGetContents handle
    hPutStr handle (pack [32, 2, 0, 0]) -- CONNACK
    handleConnection handle
