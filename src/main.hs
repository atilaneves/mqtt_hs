module Main where

import Network.Simple.TCP
import Network.Socket (isWritable, isReadable)
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
main = withSocketsDo $ do
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


handleResponse :: Socket -> Subscriptions -> BS.ByteString -> Response Socket -> IO ()
handleResponse socket subsVar bytes response =
    case response of
      CloseConnection -> return ()
      ClientMessages (replies, subs') -> do
        writeIORef subsVar subs'
        handleReplies replies
        readable <- isReadable socket
        let closed = not readable
        if null replies || closed
        then return ()
        else handleConnectionImpl socket subsVar bytes


handleReplies :: [Reply Socket] -> IO ()
handleReplies [] = return ()
handleReplies (reply:replies) = do
  let (replySocket, replyPacket) = reply
  writable <- isWritable replySocket
  if writable
  then do
    sendLazy replySocket replyPacket
    handleReplies replies
  else return ()
