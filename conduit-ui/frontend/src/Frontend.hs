{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE LambdaCase #-}

{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecursiveDo #-}

module Frontend where

import Common.WebSocketMessage
import Frontend.Page.EventSource.CronTimer (eventSource_cronTimer)
import Frontend.Page.DataNetwork.OneClickRun (dataNetwork_oneClickRun)

import Prelude

import GHC.Int (Int64)
import qualified Data.ByteString as B
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import qualified Data.Aeson as J
import Obelisk.Frontend
import Obelisk.Route
import Reflex.Dom.Core

import Control.Monad.IO.Class (MonadIO, liftIO)

import Common.Api
import Common.Route
import Obelisk.Generated.Static

import Control.Monad.Fix (MonadFix)
import Data.Default (def)
import Data.String.Conversions (cs)

import Reflex (never)
import Obelisk.Route.Frontend (RoutedT, RouteToUrl, SetRoute, routeLink, askRoute, subRoute, subRoute_)

import qualified Obelisk.ExecutableConfig as Cfg
import Text.Regex.TDFA ((=~))
import Control.Applicative ((<|>))
import Data.Maybe (fromJust)
import System.Random (randomRIO)

combine :: (b -> c -> d) -> (a -> b) -> (a -> c) -> (a -> d)
combine op f g = \x -> f x `op` g x

(&&&) :: (a -> Bool) -> (a -> Bool) -> a -> Bool
(&&&) = combine (&&)
infixr 3 &&&


htmlHeader :: DomBuilder t m => m ()
htmlHeader = do
  elAttr "link" ( "rel" =: "stylesheet"
               <> "href" =: "https://cdn.jsdelivr.net/npm/semantic-ui@2.3.3/dist/semantic.min.css") blank

nav :: forall t js m. ( DomBuilder t m, Prerender js m
        , PerformEvent t m, TriggerEvent t m, PostBuild t m
        , RouteToUrl (R FrontendRoute) m, SetRoute t (R FrontendRoute) m) => m ()
nav = do
  divClass "item" $ do
    elClass "h4" "ui header" $ text "数据网络"
    divClass "menu" $ do
      divClass "item" $ routeLink (FrontendRoute_DataNetwork :/ DataNetworkRoute_OneClickRun :/ ()) $ text "一键实时" 
      divClass "item" $ routeLink (FrontendRoute_DataNetwork :/ DataNetworkRoute_LogicFragement :/ ()) $ text "逻辑碎片"
      divClass "item" $ routeLink (FrontendRoute_DataNetwork :/ DataNetworkRoute_DataConduit :/ ()) $ text "数据导管"
      divClass "item" $ routeLink (FrontendRoute_DataNetwork :/ DataNetworkRoute_DataCircuit :/ ()) $ text "数据电路" 
  divClass "item" $ do
    elClass "h4" "ui header" $ text "事件源"
    divClass "menu" $ do
      divClass "item" $ routeLink (FrontendRoute_EventSource :/ EventSourceRoute_CronTimer :/ ()) $ text "Cron定时器"      
      divClass "item" $ routeLink (FrontendRoute_EventSource :/ EventSourceRoute_HttpRequest :/ ()) $ text "HTTP请求"
      divClass "item" $ routeLink (FrontendRoute_EventSource :/ EventSourceRoute_FileWatcher :/ ()) $ text "文件监控"

  divClass "item" $ do
    elClass "h4" "ui header" $ text "数据源"
    divClass "menu" $ do
      divClass "item" $ routeLink (FrontendRoute_DataSource :/ DataSourceRoute_Kafka :/ ()) $ text "Kafka"
      divClass "item" $ routeLink (FrontendRoute_DataSource :/ DataSourceRoute_WebSocket :/ ()) $ text "WebSocket"
      divClass "item" $ routeLink (FrontendRoute_DataSource :/ DataSourceRoute_RestAPI :/ ()) $ text "RestAPI"
      divClass "item" $ routeLink (FrontendRoute_DataSource :/ DataSourceRoute_SQLCursor :/ ()) $ text "SQL游标"
      divClass "item" $ routeLink (FrontendRoute_DataSource :/ DataSourceRoute_Minio :/ ()) $ text "Minio"
      
  divClass "item" $ do
    elClass "h4" "ui header" $ text "状态容器"
    divClass "menu" $ do
      divClass "item" $ routeLink (FrontendRoute_StateContainer :/ StateContainerRoute_PostgreSQL :/ ()) $ text "PostgreSQL"
      divClass "item" $ routeLink (FrontendRoute_StateContainer :/ StateContainerRoute_RocksDB :/ ()) $ text "RocksDB"
      divClass "item" $ routeLink (FrontendRoute_StateContainer :/ StateContainerRoute_SQLLite :/ ()) $ text "SQLLite"
      
  divClass "item" $ do
    elClass "h4" "ui header" $ text "函数式组件库"
    divClass "menu" $ do
      divClass "item" $ routeLink (FrontendRoute_LambdaLib :/ LambdaLibRoute_SerDe :/ ()) $ text "SerDe"
      divClass "item" $ routeLink (FrontendRoute_LambdaLib :/ LambdaLibRoute_UDF :/ ()) $ text "UDF"
      divClass "item" $ routeLink (FrontendRoute_LambdaLib :/ LambdaLibRoute_UDAF :/ ()) $ text "UDAF"
      divClass "item" $ routeLink (FrontendRoute_LambdaLib :/ LambdaLibRoute_UDTF :/ ()) $ text "UDTF"
  divClass "item" $ do
    elClass "h4" "ui header" $ text "实时ETL引擎"
    divClass "menu" $ do
      divClass "item" $ text "Conduit"
      divClass "item" $ text "SQL"
      divClass "item" $ text "规则引擎"
  divClass "item" $ do
    elClass "h4" "ui header" $ text "实时服务接口"
    divClass "menu" $ do
      divClass "item" $ text "PostgREST"
      divClass "item" $ text "ElasticSearch"
      divClass "item" $ text "Hbase"
      divClass "item" $ text "Kudu"
  divClass "item" $ do
    elClass "h4" "ui header" $ text "实时BI报表"
    divClass "menu" $ do
      divClass "item" $ text "公共报表"
      divClass "item" $ text "个人报表"
      divClass "item" $ text "报表开发器"
  divClass "item" $ do
    elClass "h4" "ui header" $ text "实时通知接口"
    divClass "menu" $ do
      divClass "item" $ text "WebHook"
      divClass "item" $ text "Email"
  divClass "item" $ do
    elClass "h4" "ui header" $ text "数据存储接口"
    divClass "menu" $ do
      divClass "item" $ text "Minio"
      divClass "item" $ text "HDFS"
      divClass "item" $ text "Ftp/SFtp"

page :: forall t js m.
  ( DomBuilder t m, Prerender js m
  , MonadFix m, MonadHold t m
  , PerformEvent t m, TriggerEvent t m, PostBuild t m
  )
  => Event t WSResponseMessage
  -> RoutedT t (R FrontendRoute) m (Event t WSRequestMessage)
page wsResponseEvt = do
  pb <- getPostBuild 
  fmap switchDyn $ subRoute $ \case
      FrontendRoute_Main -> text "my main" >> return never
      FrontendRoute_DataNetwork -> fmap switchDyn $ subRoute $ \case
        DataNetworkRoute_OneClickRun -> dataNetwork_oneClickRun wsResponseEvt
        DataNetworkRoute_LogicFragement -> text " DataNetworkRoute_LogicFragement" >> return never
        DataNetworkRoute_DataConduit -> text " DataNetworkRoute_DataConduit" >> return never
        DataNetworkRoute_DataCircuit -> text " DataNetworkRoute_DataCircuit" >> return never        
      FrontendRoute_EventSource -> fmap switchDyn $ subRoute $ \case
        EventSourceRoute_HttpRequest -> text "my EventSourceRoute_HttpRequest" >> return never
        EventSourceRoute_CronTimer -> eventSource_cronTimer wsResponseEvt
        EventSourceRoute_FileWatcher -> text "my EventSourceRoute_FileWatcher" >> return never
      FrontendRoute_DataSource -> fmap switchDyn $ subRoute $ \case
        DataSourceRoute_Kafka -> text "my DataSourceRoute_Kafka" >> return never
        DataSourceRoute_WebSocket -> text "my DataSourceRoute_WebSocket" >> return never
        DataSourceRoute_RestAPI -> text "my DataSourceRoute_RestAPI" >> return never        
        DataSourceRoute_SQLCursor -> text "my DataSourceRoute_SQLCursor" >> return never
        DataSourceRoute_Minio -> text "my DataSourceRoute_Minio" >> return never        
      FrontendRoute_StateContainer -> fmap switchDyn $ subRoute $ \case
        StateContainerRoute_PostgreSQL -> text "my StateContainerRoute_PostgreSQL" >> return never
        StateContainerRoute_RocksDB -> text "my StateContainerRoute_RocksDB" >> return never
        StateContainerRoute_SQLLite -> text "my StateContainerRoute_SQLLite" >> return never
      FrontendRoute_LambdaLib -> fmap switchDyn $ subRoute $ \case
        LambdaLibRoute_SerDe -> text "my LambdaLibRoute_SerDe" >> return never
        LambdaLibRoute_UDF -> text "my LambdaLibRoute_UDF" >> return never
        LambdaLibRoute_UDAF -> text "my LambdaLibRoute_UDAF" >> return never
        LambdaLibRoute_UDTF -> text "my LambdaLibRoute_UDTF" >> return never

handleWSRequest :: forall t m js.
  ( DomBuilder t m, Prerender js m, MonadHold t m
  , PerformEvent t m, TriggerEvent t m, PostBuild t m)
  => T.Text -> Event t WSRequestMessage -> m (Event t WSResponseMessage)
handleWSRequest wsURL wsRequest =
  prerender (return never) $ do
    ws <- webSocket wsURL $
      def & webSocketConfig_send .~ (fmap ((:[]) . J.encode) wsRequest)
    return $ fmap (fromJust . J.decode . cs) (_webSocket_recv ws)

frontend :: Frontend (R FrontendRoute)
frontend = Frontend
  { _frontend_head = htmlHeader
  , _frontend_body = do
      Just configRoute <- liftIO $ Cfg.get "config/common/route"
      let hostPort = fromJust $  T.stripPrefix "https://" configRoute
                             <|> T.stripPrefix "http://" configRoute
                             <|> Just "localhost:8000"
      let wsURL = "ws://" <> hostPort <> "/wsConduit"
      rec
        wsResponseEvt <- handleWSRequest wsURL wsRequestEvt
--        (wsInitEvt, wsRecvEvt) <- headTailE =<< handleWSRequest wsURL wsSendEvt
--        wsInitST <- holdDyn Nothing (fmap Just wsInitEvt)
        wsRequestEvt <- do
          divClass "ui message icon" $ do
            elClass "i" "notched circle loading icon" blank
            elClass "h1" "ui header" $
              routeLink (FrontendRoute_Main :/ ()) $ text "实时数据中台" 
          divClass "ui grid" $ do
            divClass "ui two wide column vertical menu visible" $ nav
            divClass "ui fourteen wide column container" $ page wsResponseEvt
      return ()
  }

