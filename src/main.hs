module Main where

import Network.Simple.TCP
import Network.Socket (isWritable, isReadable)
import Control.Concurrent
import qualified Data.ByteString.Lazy as BS
import qualified Data.ByteString.Lazy as BS (null, append)
import Data.ByteString.Lazy (empty, fromStrict)
import Mqtt.Broker (unsubscribe, serviceRequest, Reply, Subscription,
                    Response(ClientMessages), Response(CloseConnection))
import Mqtt.Stream (nextMessage, mqttStream)
import Data.IORef


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


handleReply :: Reply Socket -> IO ()
handleReply (socket, packet) = do
  writable <- isWritable socket
  if writable
  then sendLazy socket packet
  else return ()


handleReplies :: [Reply Socket] -> IO ()
handleReplies replies = mapM_ handleReply replies
