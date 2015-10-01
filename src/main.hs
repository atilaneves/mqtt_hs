module Main where

--import Network
import Network.Simple.TCP
import Control.Concurrent
import System.IO (Handle, hSetBinaryMode, hClose, hIsClosed)
import qualified Data.ByteString.Lazy as BS
import qualified Data.ByteString.Lazy as BS (null, append)
import Data.ByteString.Lazy (hPutStr, hGet, append, empty, pack, unpack, hGetNonBlocking)
import Mqtt.Broker (unsubscribe, serviceRequest, Reply, Subscription,
                    Response(ClientMessages), Response(CloseConnection))
import Mqtt.Stream (nextMessage, mqttStream)
import Data.IORef


type SubscriptionIO = Subscription Handle
type Subscriptions = IORef [Subscription Handle]


main :: IO ()
-- main = withSocketsDo $ do
--          subsVar <- newIORef [] -- empty subscriptions list
--          socket <- listenOn $ PortNumber 1883
--          socketHandler subsVar socket
--          return ()
main = serve HostAny "1883" handleConnection


handleConnection :: (Socket, SockAddr) -> IO ()
handleConnection _ = do
  putStrLn "Foo!"
  return ()


-- socketHandler :: Subscriptions -> Socket -> IO ThreadId
-- socketHandler subs socket = do
--   (handle, _, _) <- accept socket
--   hSetBinaryMode handle True
--   forkIO $ handleConnection handle subs
--   socketHandler subs socket


-- handleConnection :: Handle -> Subscriptions -> IO ()
-- handleConnection handle subsVar = do
--   handleConnectionImpl handle subsVar empty
--   modifyIORef' subsVar (unsubscribe handle)
--   hClose handle


-- handleConnectionImpl :: Handle -> Subscriptions -> BS.ByteString -> IO ()
-- handleConnectionImpl handle subsVar bytes = do
--   let (msg, bytes') = nextMessage bytes
--   if BS.null msg
--   then do
--     bytes'' <- hGetNonBlocking handle 1024
--     if BS.null bytes''
--     then do
--       handleConnectionImpl handle subsVar bytes'
--     else do
--       handleConnectionImpl handle subsVar (bytes' `BS.append` bytes'')
--   else do
--     subs <- readIORef subsVar
--     let response = serviceRequest handle msg subs
--     handleResponse handle subsVar bytes' response


-- handleResponse :: Handle -> Subscriptions -> BS.ByteString -> Response Handle -> IO ()
-- handleResponse handle subsVar bytes response =
--     case response of
--       CloseConnection -> return ()
--       ClientMessages (replies, subs') -> do
--         writeIORef subsVar subs'
--         handleReplies replies
--         closed <- hIsClosed handle
--         if null replies || closed
--         then return ()
--         else handleConnectionImpl handle subsVar bytes


-- handleReplies :: [Reply Handle] -> IO ()
-- handleReplies [] = return ()
-- handleReplies (reply:replies) = do
--   closed <- hIsClosed replyHandle
--   if closed
--   then return ()
--   else do
--     hPutStr replyHandle replyPacket
--     handleReplies replies
--     where (replyHandle, replyPacket) = reply
