{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Cardano.DbSync.Plugin.TxBody
  ( defDbSyncTxBodyPlugin
  , insertTxBody
  )
where
import           Cardano.Binary ( serialize' )
import           Cardano.BM.Trace ( Trace )

import           Control.Monad.Logger ( LoggingT )
import           Control.Monad.Trans.Control (MonadBaseControl)
import           Control.Monad.Trans.Except.Extra
import           Control.Monad.Trans.Reader ( ReaderT )

import qualified Cardano.Chain.Block as Ledger
import qualified Cardano.Chain.UTxO as Ledger

import           Cardano.Crypto ( serializeCborHash )

import qualified Cardano.Db as DB
import qualified Cardano.DbSync.Era.Byron.Util as Byron
import           Cardano.DbSync.Error
import           Cardano.DbSync.Plugin
import           Cardano.DbSync.Types

import           Cardano.Prelude

import           Database.Persist.Sql ( SqlBackend )

import           Ouroboros.Consensus.Byron.Ledger ( ByronBlock(..) )


insertTxBody 
    :: Trace IO Text -> DbSyncEnv -> CardanoBlockTip
    -> ReaderT SqlBackend (LoggingT IO) (Either DbSyncNodeError ())
insertTxBody _ _ blkTip  =
  case blkTip of
    ByronBlockTip blk _ -> insertByronBody blk
    _ -> return $ Right ()

insertByronBody
    :: ByronBlock
    -> ReaderT SqlBackend (LoggingT IO) (Either DbSyncNodeError ())
insertByronBody blk = 
  runExceptT $ 
    case byronBlockRaw blk of
      Ledger.ABOBBlock ablk -> insertBlock ablk
      _ -> return ()
 where
  insertBlock
      :: (MonadBaseControl IO m, MonadIO m)
      => Ledger.ABlock ByteString
      -> ExceptT DbSyncNodeError (ReaderT SqlBackend m) ()
  insertBlock ablk =
    mapM_ insertTx $ Byron.blockPayload ablk

  insertTx
      :: (MonadBaseControl IO m, MonadIO m)
      => Ledger.TxAux
      -> ExceptT DbSyncNodeError (ReaderT SqlBackend m) ()
  insertTx tx =
    let hash = Byron.unTxHash $ serializeCborHash (Ledger.taTx tx)
        body = serialize' $ Ledger.taTx tx
    in  
      void $ lift . DB.insertTxBody $ DB.TxBody { DB.txBodyHash = hash
                                                , DB.txBodyBody = body
                                                }

defDbSyncTxBodyPlugin :: DbSyncNodePlugin
defDbSyncTxBodyPlugin = 
  DbSyncNodePlugin 
    { plugOnStartup     = []
    , plugInsertBlock   = [insertTxBody]
    , plugRollbackBlock = []
    }
