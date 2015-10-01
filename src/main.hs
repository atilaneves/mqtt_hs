module Main where

--import Network
import Network.Simple.TCP
import Control.Concurrent
import System.IO (Handle, hSetBinaryMode, hClose, hIsClosed)
import qualified Data.ByteString.Lazy as BS
import qualified Data.ByteString.Lazy as BS (null, append)
import Data.ByteString.Lazy (hPutStr, hGet, append, empty, pack, unpack, hGetNonBlocking, fromStrict)
import Mqtt.Broker (unsubscribe, serviceRequest, Reply, Subscription,
                    Response(ClientMessages), Response(CloseConnection))
import Mqtt.Stream (nextMessage, mqttStream)
import Data.IORef


type SubscriptionIO = Subscription Handle
type Subscriptions = IORef [Subscription Socket]


main :: IO ()
-- main = withSocketsDo $ do
--          subsVar <- newIORef [] -- empty subscriptions list
--          socket <- listenOn $ PortNumber 1883
--          socketHandler subsVar socket
--          return ()
main = do
  subsVar <- newIORef [] -- empty subscriptions list
  serve HostAny "1883" (handleConnection subsVar)


handleConnection :: Subscriptions -> (Socket, SockAddr) -> IO ()
handleConnection subsVar (socket, _) = do
  handleConnectionImpl socket subsVar empty
  return ()


handleConnectionImpl :: Socket -> Subscriptions -> BS.ByteString -> IO ()
handleConnectionImpl socket subsVar bytes = do
  let (msg, bytes') = nextMessage bytes
  if BS.null msg
  then do
    received <- recv socket 1024
    case received of
      Nothing -> return ()
      Just strictBytes -> do
        let bytes'' = fromStrict strictBytes
        if BS.null bytes''
        then handleConnectionImpl socket subsVar bytes'
        else handleConnectionImpl socket subsVar (bytes' `BS.append` bytes'')
  else do
    subs <- readIORef subsVar
    let response = serviceRequest socket msg subs
    handleResponse socket subsVar bytes' response


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


handleResponse :: Socket -> Subscriptions -> BS.ByteString -> Response Socket -> IO ()
handleResponse socket subsVar bytes response =
    case response of
      CloseConnection -> return ()
      ClientMessages (replies, subs') -> do
        writeIORef subsVar subs'
        handleReplies replies
        --closed <- hIsClosed socket
        if null replies -- || closed
        then return ()
        else handleConnectionImpl socket subsVar bytes


handleReplies :: [Reply Socket] -> IO ()
handleReplies [] = return ()
handleReplies (reply:replies) = do
  sendLazy replySocket replyPacket
  handleReplies replies
  where (replySocket, replyPacket) = reply
  -- closed <- hIsClosed replyHandle
  -- if closed
  -- then return ()
  -- else do
  --   hPutStr replyHandle replyPacket
  --   handleReplies replies
  --   where (replyHandle, replyPacket) = reply
